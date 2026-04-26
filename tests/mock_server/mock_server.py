#!/usr/bin/env python3
"""
otk mock REST server
====================
Provides two endpoint sets for testing otk$rest and otk$ansible:

  1. httpbin-style endpoints  (/get, /post, /put, /patch, /delete,
                               /bearer, /basic-auth, /status, /slow, /headers)

  2. Ansible Tower API v2     (/api/v2/ping/
                               /api/v2/job_templates/{id}/launch/
                               /api/v2/jobs/{id}/
                               /api/v2/jobs/{id}/stdout/
                               /api/v2/jobs/{id}/cancel/)

Job template behaviour (template_id controls outcome):
  1   -> successful after 2 GET /jobs/{id}/ calls
  2   -> failed     after 2 calls
  3   -> error      after 2 calls
  999 -> always running (use for cancel tests and timeout tests)
  any other -> 404

Admin:
  POST /admin/reset  -- clears all job state between test runs

Usage:
  python mock_server.py [--host 0.0.0.0] [--port 8765]
"""

import argparse
import base64
import time
from flask import Flask, request, jsonify, make_response

app = Flask(__name__)

# ------------------------------------------------------------------ #
# Job state store
# ------------------------------------------------------------------ #
_job_counter = 1000
_jobs = {}   # job_id -> { template_id, call_count, forced_status? }

VALID_TEMPLATES = {1, 2, 3, 999}


def _next_job_id():
    global _job_counter
    _job_counter += 1
    return _job_counter


def _job_status(job: dict) -> str:
    """
    State machine. Jobs start 'running' and reach a terminal state
    after 2 GET /jobs/{id}/ calls (call_count is incremented by the
    route handler before calling this function).

    forced_status overrides everything — used by cancel.
    """
    if 'forced_status' in job:
        return job['forced_status']

    tid   = job['template_id']
    calls = job['call_count']

    if tid == 999:
        return 'running'
    if calls < 2:
        return 'running'
    if tid == 2:
        return 'failed'
    if tid == 3:
        return 'error'
    return 'successful'


# ------------------------------------------------------------------ #
# Auth helpers
# ------------------------------------------------------------------ #
def _auth_header() -> str:
    return request.headers.get('Authorization', '')


def _verify_bearer() -> bool:
    return _auth_header().startswith('Bearer ')


def _verify_basic(expected_user: str, expected_pass: str) -> bool:
    h = _auth_header()
    if not h.startswith('Basic '):
        return False
    try:
        creds = base64.b64decode(h[6:]).decode('utf-8')
        user, pw = creds.split(':', 1)
        return user == expected_user and pw == expected_pass
    except Exception:
        return False


# ------------------------------------------------------------------ #
# httpbin-style endpoints
# ------------------------------------------------------------------ #

@app.route('/get', methods=['GET'])
def rest_get():
    return jsonify({
        'method':  'GET',
        'url':     request.url,
        'headers': dict(request.headers),
        'args':    dict(request.args),
        'origin':  request.remote_addr,
    })


@app.route('/post', methods=['POST'])
def rest_post():
    return jsonify({
        'method':  'POST',
        'url':     request.url,
        'headers': dict(request.headers),
        'data':    request.get_data(as_text=True),
        'json':    request.get_json(silent=True),
    })


@app.route('/put', methods=['PUT'])
def rest_put():
    return jsonify({
        'method':  'PUT',
        'url':     request.url,
        'headers': dict(request.headers),
        'data':    request.get_data(as_text=True),
        'json':    request.get_json(silent=True),
    })


@app.route('/patch', methods=['PATCH'])
def rest_patch():
    return jsonify({
        'method':  'PATCH',
        'url':     request.url,
        'headers': dict(request.headers),
        'data':    request.get_data(as_text=True),
        'json':    request.get_json(silent=True),
    })


@app.route('/delete', methods=['DELETE'])
def rest_delete():
    return jsonify({
        'method':  'DELETE',
        'url':     request.url,
        'headers': dict(request.headers),
    })


@app.route('/bearer', methods=['GET'])
def rest_bearer():
    if _verify_bearer():
        return jsonify({'authenticated': True, 'token': _auth_header()[7:]})
    return jsonify({'authenticated': False}), 401


@app.route('/basic-auth/<expected_user>/<expected_pass>', methods=['GET'])
def rest_basic_auth(expected_user, expected_pass):
    if _verify_basic(expected_user, expected_pass):
        return jsonify({'authenticated': True, 'user': expected_user})
    resp = make_response(jsonify({'authenticated': False}), 401)
    resp.headers['WWW-Authenticate'] = 'Basic realm="Test"'
    return resp


@app.route('/status/<int:code>',
           methods=['GET', 'POST', 'PUT', 'PATCH', 'DELETE'])
def rest_status(code):
    return make_response('', code)


@app.route('/slow/<int:seconds>', methods=['GET'])
def rest_slow(seconds):
    """Sleep then respond — used to trigger read timeout tests."""
    time.sleep(seconds)
    return jsonify({'slept': seconds})


@app.route('/headers', methods=['GET'])
def rest_headers():
    """Return the request headers as JSON — used to verify custom header passing."""
    return jsonify({'headers': dict(request.headers)})


# ------------------------------------------------------------------ #
# Ansible Tower API v2 endpoints
# ------------------------------------------------------------------ #

@app.route('/api/v2/ping/', methods=['GET'])
def ansible_ping():
    return jsonify({
        'version':     '3.8.0',
        'active_node': 'mock-tower',
        'ha':          False,
        'license_type': 'open',
        'time':        '2026-04-25T10:00:00.000000Z',
    })


@app.route('/api/v2/job_templates/<int:template_id>/launch/', methods=['POST'])
def ansible_launch(template_id):
    if template_id not in VALID_TEMPLATES:
        return jsonify({'detail': 'Not found.'}), 404

    job_id = _next_job_id()
    _jobs[job_id] = {'template_id': template_id, 'call_count': 0}

    print(f'  [ansible] launched template={template_id} -> job_id={job_id}')

    return jsonify({
        'job':    job_id,
        'status': 'new',
        'type':   'job',
        'url':    f'/api/v2/jobs/{job_id}/',
    }), 201


@app.route('/api/v2/jobs/<int:job_id>/', methods=['GET'])
def ansible_get_job(job_id):
    if job_id not in _jobs:
        return jsonify({'detail': 'Not found.'}), 404

    job = _jobs[job_id]
    job['call_count'] += 1
    status   = _job_status(job)
    terminal = status in ('successful', 'failed', 'error', 'canceled')

    print(f'  [ansible] get_job id={job_id} call={job["call_count"]} status={status}')

    return jsonify({
        'id':           job_id,
        'type':         'job',
        'url':          f'/api/v2/jobs/{job_id}/',
        'status':       status,
        'failed':       status in ('failed', 'error'),
        'started':      '2026-04-25T10:00:00.000000Z',
        'finished':     '2026-04-25T10:01:00.000000Z' if terminal else None,
        'elapsed':      60.0 if terminal else None,
        'job_template': job['template_id'],
        'extra_vars':   '{}',
    })


@app.route('/api/v2/jobs/<int:job_id>/stdout/', methods=['GET'])
def ansible_stdout(job_id):
    if job_id not in _jobs:
        return make_response('Not found.', 404)

    output = (
        'PLAY [all] ************************************************************\n'
        '\n'
        'TASK [Gathering Facts] ************************************************\n'
        'ok: [localhost]\n'
        '\n'
        'TASK [otk mock deployment task] ***************************************\n'
        'changed: [localhost]\n'
        '\n'
        'PLAY RECAP ************************************************************\n'
        'localhost : ok=2  changed=1  unreachable=0  failed=0  skipped=0\n'
    )
    return make_response(output, 200, {'Content-Type': 'text/plain'})


@app.route('/api/v2/jobs/<int:job_id>/cancel/', methods=['POST'])
def ansible_cancel(job_id):
    if job_id not in _jobs:
        return jsonify({'detail': 'Not found.'}), 404

    # Check current status without incrementing call_count
    status = _job_status(_jobs[job_id])
    if status in ('successful', 'failed', 'error', 'canceled'):
        # Tower returns 405 when job is already terminal
        return make_response('', 405)

    _jobs[job_id]['forced_status'] = 'canceled'
    print(f'  [ansible] canceled job_id={job_id}')
    return make_response('', 202)


# ------------------------------------------------------------------ #
# Admin — reset between test runs
# ------------------------------------------------------------------ #

@app.route('/admin/reset', methods=['POST'])
def admin_reset():
    global _job_counter, _jobs
    _job_counter = 1000
    _jobs = {}
    print('  [admin] state reset')
    return jsonify({'reset': True})


# ------------------------------------------------------------------ #
if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='otk mock REST server')
    parser.add_argument('--host', default='0.0.0.0')
    parser.add_argument('--port', type=int, default=8765)
    args = parser.parse_args()

    print(f'\notk mock server  http://{args.host}:{args.port}')
    print('─' * 60)
    print('REST endpoints:')
    print('  GET  /get             POST /post            PUT  /put')
    print('  PATCH /patch          DELETE /delete')
    print('  GET  /bearer          GET  /basic-auth/{u}/{p}')
    print('  GET  /status/{code}   GET  /slow/{sec}      GET  /headers')
    print('Ansible Tower endpoints:')
    print('  GET  /api/v2/ping/')
    print('  POST /api/v2/job_templates/{id}/launch/')
    print('       id=1 -> successful | id=2 -> failed | id=3 -> error')
    print('       id=999 -> always running (cancel / timeout tests)')
    print('  GET  /api/v2/jobs/{id}/')
    print('  GET  /api/v2/jobs/{id}/stdout/')
    print('  POST /api/v2/jobs/{id}/cancel/')
    print('Admin:')
    print('  POST /admin/reset     clears all job state')
    print('─' * 60)

    app.run(host=args.host, port=args.port, debug=False)

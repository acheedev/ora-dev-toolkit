CREATE OR REPLACE PACKAGE otk$ansible IS

    ----------------------------------------------------------------------
    -- Requires Oracle 19c or later.
    -- Depends on: otk$rest (HTTP calls), otk$json (response parsing)
    --
    -- Targets Ansible Tower / AWX REST API v2.
    -- All calls go to the same base URL with the same credentials,
    -- so configure() is called once and stores session-level state.
    ----------------------------------------------------------------------

    ----------------------------------------------------------------------
    -- Job status constants — match Ansible Tower's status field values
    ----------------------------------------------------------------------
    c_status_new        CONSTANT VARCHAR2(20) := 'new';
    c_status_pending    CONSTANT VARCHAR2(20) := 'pending';
    c_status_waiting    CONSTANT VARCHAR2(20) := 'waiting';
    c_status_running    CONSTANT VARCHAR2(20) := 'running';
    c_status_successful CONSTANT VARCHAR2(20) := 'successful';
    c_status_failed     CONSTANT VARCHAR2(20) := 'failed';
    c_status_error      CONSTANT VARCHAR2(20) := 'error';
    c_status_canceled   CONSTANT VARCHAR2(20) := 'canceled';

    ----------------------------------------------------------------------
    -- Session configuration
    --
    -- Call once per session before making any API calls, e.g. in a
    -- package initialiser or at the top of a procedure.
    --
    -- p_base_url        : Tower base URL, no trailing slash
    --                     e.g. 'https://ansible-tower.company.com'
    -- p_bearer          : OAuth2 token (preferred over basic auth)
    -- p_basic_user/pass : Basic auth fallback
    -- p_job_timeout_sec : Default maximum seconds wait_for_job will poll.
    --                     Override per-call by passing a non-NULL value
    --                     to wait_for_job's p_timeout_sec parameter.
    -- p_job_poll_sec    : Default seconds between status polls in
    --                     wait_for_job. Same per-call override applies.
    ----------------------------------------------------------------------
    PROCEDURE configure(
        p_base_url        IN VARCHAR2,
        p_bearer          IN VARCHAR2 DEFAULT NULL,
        p_basic_user      IN VARCHAR2 DEFAULT NULL,
        p_basic_pass      IN VARCHAR2 DEFAULT NULL,
        p_job_timeout_sec IN NUMBER   DEFAULT 300,
        p_job_poll_sec    IN NUMBER   DEFAULT 10
    );

    ----------------------------------------------------------------------
    -- Health check
    -- Returns TRUE if the Tower API responds to /api/v2/ping/
    ----------------------------------------------------------------------
    FUNCTION ping RETURN BOOLEAN;

    ----------------------------------------------------------------------
    -- Launch a job template
    -- Returns the new job ID on success.
    -- Raises ORA-20003 if the API call fails or Tower rejects the launch.
    --
    -- p_extra_vars : JSON object of Ansible extra vars
    --               e.g. '{"env":"prod","version":"2.1"}'
    -- p_limit      : Ansible host pattern limit (--limit equivalent)
    -- p_inventory  : Inventory ID to override the template default
    ----------------------------------------------------------------------
    FUNCTION launch_job(
        p_template_id IN NUMBER,
        p_extra_vars  IN CLOB     DEFAULT NULL,
        p_limit       IN VARCHAR2 DEFAULT NULL,
        p_inventory   IN NUMBER   DEFAULT NULL
    ) RETURN NUMBER;

    ----------------------------------------------------------------------
    -- Job inspection
    ----------------------------------------------------------------------

    -- Raw status string from Tower: new/pending/waiting/running/
    --                               successful/failed/error/canceled
    FUNCTION job_status(p_job_id IN NUMBER) RETURN VARCHAR2;

    -- TRUE if job has reached a terminal state (any of the above
    -- that are not new/pending/waiting/running)
    FUNCTION job_complete(p_job_id IN NUMBER) RETURN BOOLEAN;

    -- TRUE only if status = 'successful'
    FUNCTION job_succeeded(p_job_id IN NUMBER) RETURN BOOLEAN;

    -- Full job detail as a CLOB JSON response from /api/v2/jobs/{id}/
    FUNCTION get_job(p_job_id IN NUMBER) RETURN CLOB;

    -- Playbook stdout text from /api/v2/jobs/{id}/stdout/?format=txt
    FUNCTION get_job_output(p_job_id IN NUMBER) RETURN CLOB;

    ----------------------------------------------------------------------
    -- Poll until the job reaches a terminal state or timeout expires.
    -- Returns the final status string.
    -- Raises ORA-20002 if p_timeout_sec seconds elapse without completion.
    --
    -- NOTE: This is a blocking call. The database session is held for
    -- the duration of polling. Size p_timeout_sec to your longest
    -- expected playbook runtime. Set defaults once in configure().
    --
    -- p_timeout_sec : NULL uses the value set in configure() (default 300)
    -- p_poll_sec    : NULL uses the value set in configure() (default 10)
    ----------------------------------------------------------------------
    FUNCTION wait_for_job(
        p_job_id      IN NUMBER,
        p_timeout_sec IN NUMBER DEFAULT NULL,
        p_poll_sec    IN NUMBER DEFAULT NULL
    ) RETURN VARCHAR2;

    ----------------------------------------------------------------------
    -- Cancel a running job
    -- No-ops silently if the job is already in a terminal state.
    ----------------------------------------------------------------------
    PROCEDURE cancel_job(p_job_id IN NUMBER);

END otk$ansible;
/

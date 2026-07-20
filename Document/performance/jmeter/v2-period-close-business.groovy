def common = evaluate(new File('/tests/v2-common.groovy'))
def api = common.makeContext(props, vars, ctx)

def periodId = vars.get('periodId')
def closeRequestId = vars.get('closeRequestId')
api.requireCondition(periodId != null && periodId.trim().length() > 0, 'periodId variable was not initialized.')
api.requireCondition(closeRequestId != null && closeRequestId.trim().length() > 0, 'closeRequestId variable was not initialized.')

def preview = api.request('GET', "/periods/${periodId}/close-preview", null, [200])
api.requireCondition(preview.json?.canClose == true, "Period ${periodId} should be closeable: ${preview.text}")
api.requireCondition((preview.json?.version as Integer) >= 1, "Period ${periodId} preview did not include a valid version.")

def closeBody = [
    requestId: closeRequestId,
    expectedVersion: preview.json.version as Integer
]
def closed = api.request('POST', "/periods/${periodId}/close", closeBody, [200])
api.requireCondition(closed.json?.replayed == false, "First close for period ${periodId} must not be replayed.")
api.requireCondition(closed.json?.requestId?.toString()?.equalsIgnoreCase(closeRequestId), "Close requestId mismatch for period ${periodId}.")

def replay = api.request('POST', "/periods/${periodId}/close", closeBody, [200])
api.requireCondition(replay.json?.replayed == true, "Second close for period ${periodId} must be replayed.")

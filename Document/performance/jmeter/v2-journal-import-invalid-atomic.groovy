def common = evaluate(new File('/tests/v2-common.groovy'))
def api = common.makeContext(props, vars, ctx)

def runTag = api.propertyValue('runTag', 'local')
def debitAccountCode = api.propertyValue('debitAccountCode', '')
api.requireCondition(debitAccountCode.trim().length() > 0, 'debitAccountCode JMeter property is required.')

def unique = "${runTag}-${ctx.getThreadNum()}-${vars.getIteration()}"
def reference = "JM-BAD-${unique}"
def csv = """EntryDate,ReferenceNo,Description,AccountCode,Debit,Credit
2026-04-01,${reference},Valid debit row,${debitAccountCode},50.00,0
2026-04-01,${reference},Invalid credit row,NO_SUCH_ACCOUNT,0,50.00
"""

def validation = api.multipartCsv('/journal-imports/validate', csv, "invalid-${unique}.csv", [
    IdempotencyKey: "invalid-${unique}",
    Atomic: 'true'
], [200])

api.requireCondition(validation.json?.importId != null, 'Invalid atomic validation did not return importId.')
api.requireCondition((validation.json?.invalidRows as Integer) > 0, "Invalid atomic import should contain invalidRows: ${validation.text}")

def importId = validation.json.importId.toString()
def commit = api.request('POST', "/journal-imports/${importId}/commit", null, [400])
api.requireCondition(commit.text.contains('Atomic journal import contains invalid rows'),
    "Invalid atomic commit returned unexpected body: ${commit.text}")

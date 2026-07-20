import java.util.Locale

def common = evaluate(new File('/tests/v2-common.groovy'))
def api = common.makeContext(props, vars, ctx)

def runTag = api.propertyValue('runTag', 'local')
def debitAccountCode = api.propertyValue('debitAccountCode', '')
def creditAccountCode = api.propertyValue('creditAccountCode', '')
api.requireCondition(debitAccountCode.trim().length() > 0, 'debitAccountCode JMeter property is required.')
api.requireCondition(creditAccountCode.trim().length() > 0, 'creditAccountCode JMeter property is required.')

int rows = api.propertyValue('journalRows', '20') as int
if (rows < 2) {
    rows = 2
}
if (rows % 2 != 0) {
    rows += 1
}
int entryCount = rows / 2
def unique = "${runTag}-${ctx.getThreadNum()}-${vars.getIteration()}"

def csv = new StringBuilder()
csv.append('EntryDate,ReferenceNo,Description,AccountCode,Debit,Credit\n')
(1..entryCount).each { index ->
    def reference = "JM-IMP-${unique}-${index}"
    def amount = String.format(Locale.US, '%.2f', 25.00d + (index % 100))
    csv.append("2026-04-01,${reference},JMeter import debit ${index},${debitAccountCode},${amount},0\n")
    csv.append("2026-04-01,${reference},JMeter import credit ${index},${creditAccountCode},0,${amount}\n")
}

def idempotencyKey = "valid-${unique}"
def validation = api.multipartCsv('/journal-imports/validate', csv.toString(), "valid-${unique}.csv", [
    IdempotencyKey: idempotencyKey,
    Atomic: 'true'
], [200])

api.requireCondition(validation.json?.importId != null, 'Journal import validation did not return importId.')
api.requireCondition((validation.json?.totalRows as Integer) == rows, "Journal import totalRows mismatch: ${validation.text}")
api.requireCondition((validation.json?.invalidRows as Integer) == 0, "Valid journal import had invalid rows: ${validation.text}")

def importId = validation.json.importId.toString()
def commit = api.request('POST', "/journal-imports/${importId}/commit", null, [200])
api.requireCondition(commit.json?.replayed == false, "First commit for ${importId} must not be replayed.")
api.requireCondition(commit.json?.createdEntryIds?.size() == entryCount, "Created entry count mismatch for ${importId}: ${commit.text}")

def replay = api.request('POST', "/journal-imports/${importId}/commit", null, [200])
api.requireCondition(replay.json?.replayed == true, "Second commit for ${importId} must be replayed.")
api.requireCondition(replay.json?.createdEntryIds?.size() == entryCount, "Replay entry count mismatch for ${importId}: ${replay.text}")

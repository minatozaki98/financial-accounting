import java.util.UUID

def common = evaluate(new File('/tests/v2-common.groovy'))
def api = common.makeContext(props, vars, ctx)

def runTag = api.propertyValue('runTag', 'local')
def bankAccountId = api.propertyValue('bankAccountId', '') as Integer
def exactReference = api.propertyValue('exactReference', '')
def exactDate = api.propertyValue('exactDate', '2026-06-15')
def exactAmount = new BigDecimal(api.propertyValue('exactAmount', '321.45'))
def ambiguousDate = api.propertyValue('ambiguousDate', '2026-06-16')
def ambiguousAmount = new BigDecimal(api.propertyValue('ambiguousAmount', '654.32'))
def unique = "${runTag}-${ctx.getThreadNum()}-${vars.getIteration()}"

api.requireCondition(bankAccountId > 0, 'bankAccountId JMeter property is required.')
api.requireCondition(exactReference.trim().length() > 0, 'exactReference JMeter property is required.')

def createBody = [
    periodId: 202601,
    bankAccountId: bankAccountId,
    dateFrom: '2026-01-01',
    dateTo: '2026-12-31',
    transactions: [
        [
            transactionDate: exactDate,
            amount: exactAmount,
            referenceNo: exactReference,
            description: "JMeter recon exact ${unique}"
        ],
        [
            transactionDate: ambiguousDate,
            amount: ambiguousAmount,
            description: "JMeter recon ambiguous ${unique}"
        ]
    ]
]

def created = api.request('POST', '/reconciliations', createBody, [201])
def reconciliationId = created.json?.reconciliationId?.toString()
api.requireCondition(reconciliationId != null && reconciliationId.trim().length() > 0,
    "Reconciliation create did not return reconciliationId: ${created.text}")

def matched = api.request('POST', "/reconciliations/${reconciliationId}/auto-match", null, [200])
api.requireCondition((matched.json?.matchedCount as Integer) >= 1, "Expected at least one auto-matched transaction: ${matched.text}")
api.requireCondition((matched.json?.ambiguousCount as Integer) >= 1, "Expected at least one ambiguous transaction: ${matched.text}")

def exceptions = api.request('GET', "/reconciliations/${reconciliationId}/exceptions", null, [200])
def item = exceptions.json?.items?.find { it.candidates != null && it.candidates.size() > 0 }
api.requireCondition(item != null, "Expected reconciliation exception with candidates: ${exceptions.text}")
def candidate = item.candidates[0]
api.requireCondition(candidate?.journalEntryId != null, "Expected candidate journalEntryId in exceptions: ${exceptions.text}")

def confirmed = api.request('POST', "/reconciliations/${reconciliationId}/confirm", [
    bankTransactionId: item.bankTransactionId as Long,
    journalEntryId: candidate.journalEntryId as Long,
    expectedVersion: exceptions.json.version as Integer
], [200])

def finalizeRequestId = UUID.nameUUIDFromBytes("reconciliation-finalize:${unique}".getBytes('UTF-8')).toString()
def finalizeBody = [
    requestId: finalizeRequestId,
    expectedVersion: confirmed.json.version as Integer
]
def finalized = api.request('POST', "/reconciliations/${reconciliationId}/finalize", finalizeBody, [200])
api.requireCondition(finalized.json?.replayed == false, "First reconciliation finalize must not be replayed: ${finalized.text}")

def replay = api.request('POST', "/reconciliations/${reconciliationId}/finalize", finalizeBody, [200])
api.requireCondition(replay.json?.replayed == true, "Second reconciliation finalize must be replayed: ${replay.text}")

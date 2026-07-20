import java.time.LocalDate
import java.util.UUID

def common = evaluate(new File('/tests/v2-common.groovy'))
def api = common.makeContext(props, vars, ctx)

int configuredLoops = api.propertyValue('loops', '10') as int
int sequence = (ctx.getThreadNum() * configuredLoops) + vars.getIteration()
def startDate = LocalDate.parse(api.propertyValue('periodBaseDate', '2030-01-01')).plusMonths(sequence)
def endDate = startDate.withDayOfMonth(startDate.lengthOfMonth())
int periodId = (startDate.year * 100) + startDate.monthValue
def runTag = api.propertyValue('runTag', 'local')
def closeRequestId = UUID.nameUUIDFromBytes("period-close:${runTag}:${ctx.getThreadNum()}:${vars.getIteration()}".getBytes('UTF-8')).toString()

def created = api.request('POST', '/periods', [
    periodId: periodId,
    startDate: startDate.toString(),
    endDate: endDate.toString()
], [201])

api.requireCondition(created.json?.periodId?.toString() == periodId.toString(),
    "Created periodId mismatch for ${periodId}.")
api.requireCondition(created.json?.isClosed == false,
    "New benchmark period ${periodId} should be open.")

vars.put('periodId', periodId.toString())
vars.put('closeRequestId', closeRequestId)

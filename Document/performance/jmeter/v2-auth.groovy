def common = evaluate(new File('/tests/v2-common.groovy'))
def api = common.makeContext(props, vars, ctx)

def username = api.propertyValue('username', 'admin')
def password = api.propertyValue('password', 'Admin@123')
def response = api.request('POST', '/auth/login', [
    username: username,
    password: password
], [200])

api.requireCondition(response.json?.accessToken != null && response.json.accessToken.toString().trim().length() > 0,
    'Login response did not contain accessToken.')
vars.put('authToken', response.json.accessToken.toString())

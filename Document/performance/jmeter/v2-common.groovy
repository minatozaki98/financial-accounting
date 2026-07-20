import groovy.json.JsonOutput
import groovy.json.JsonSlurper
import java.net.HttpURLConnection
import java.nio.charset.StandardCharsets
import java.util.UUID

def propertyValue = { String name, String fallback ->
    def value = props.get(name)
    if (value == null || value.toString().trim().isEmpty()) {
        return fallback
    }

    return value.toString()
}

def requireCondition = { boolean condition, String message ->
    if (!condition) {
        throw new AssertionError(message)
    }
}

def parseJson = { String text ->
    if (text == null || text.trim().isEmpty()) {
        return null
    }

    return new JsonSlurper().parseText(text)
}

def makeContext = { propsArg, varsArg, ctxArg ->
    def baseUrl = propertyValue('baseUrl', 'http://host.docker.internal:5296').replaceAll('/+$', '')
    def apiVersion = propertyValue('apiVersion', '1.0')

    def request = { String method, String path, Object body, List<Integer> expectedCodes ->
        def token = varsArg.get('authToken')
        def target = path.startsWith('http') ? path : "${baseUrl}${path}"
        def connection = (HttpURLConnection) new URL(target).openConnection()
        connection.setRequestMethod(method)
        connection.setConnectTimeout(30000)
        connection.setReadTimeout(180000)
        connection.setRequestProperty('Accept', 'application/json')
        connection.setRequestProperty('X-Api-Version', apiVersion)
        if (token != null && token.trim()) {
            connection.setRequestProperty('Authorization', "Bearer ${token}")
        }

        if (body != null) {
            def payload = JsonOutput.toJson(body)
            def bytes = payload.getBytes(StandardCharsets.UTF_8)
            connection.setDoOutput(true)
            connection.setRequestProperty('Content-Type', 'application/json; charset=UTF-8')
            connection.outputStream.withCloseable { stream ->
                stream.write(bytes)
            }
        }

        int status = connection.responseCode
        def stream = status >= 400 ? connection.errorStream : connection.inputStream
        def text = stream == null ? '' : stream.getText('UTF-8')
        if (!expectedCodes.contains(status)) {
            throw new AssertionError("${method} ${target} expected ${expectedCodes} but received ${status}: ${text}")
        }

        return [
            status: status,
            text: text,
            json: parseJson(text)
        ]
    }

    def multipartCsv = { String path, String csvText, String fileName, Map<String, String> fields, List<Integer> expectedCodes ->
        def token = varsArg.get('authToken')
        def boundary = "----JMeterV2${UUID.randomUUID().toString().replace('-', '')}"
        def target = "${baseUrl}${path}"
        def connection = (HttpURLConnection) new URL(target).openConnection()
        connection.setRequestMethod('POST')
        connection.setConnectTimeout(30000)
        connection.setReadTimeout(180000)
        connection.setDoOutput(true)
        connection.setRequestProperty('Accept', 'application/json')
        connection.setRequestProperty('X-Api-Version', apiVersion)
        connection.setRequestProperty('Content-Type', "multipart/form-data; boundary=${boundary}")
        if (token != null && token.trim()) {
            connection.setRequestProperty('Authorization', "Bearer ${token}")
        }

        connection.outputStream.withCloseable { stream ->
            def write = { String value ->
                stream.write(value.getBytes(StandardCharsets.UTF_8))
            }

            fields.each { key, value ->
                write("--${boundary}\r\n")
                write("Content-Disposition: form-data; name=\"${key}\"\r\n\r\n")
                write("${value}\r\n")
            }

            write("--${boundary}\r\n")
            write("Content-Disposition: form-data; name=\"File\"; filename=\"${fileName}\"\r\n")
            write("Content-Type: text/csv\r\n\r\n")
            write(csvText)
            write("\r\n--${boundary}--\r\n")
        }

        int status = connection.responseCode
        def stream = status >= 400 ? connection.errorStream : connection.inputStream
        def text = stream == null ? '' : stream.getText('UTF-8')
        if (!expectedCodes.contains(status)) {
            throw new AssertionError("multipart POST ${target} expected ${expectedCodes} but received ${status}: ${text}")
        }

        return [
            status: status,
            text: text,
            json: parseJson(text)
        ]
    }

    return [
        baseUrl: baseUrl,
        apiVersion: apiVersion,
        propertyValue: propertyValue,
        requireCondition: requireCondition,
        request: request,
        multipartCsv: multipartCsv
    ]
}

return [
    makeContext: makeContext,
    propertyValue: propertyValue,
    requireCondition: requireCondition
]

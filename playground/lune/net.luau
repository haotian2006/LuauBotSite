export type HttpMethod = "GET" | "POST" | "PUT" | "DELETE" | "HEAD" | "OPTIONS" | "PATCH"

type HttpQueryOrHeaderMap = { [string]: string | { string } }
export type HttpQueryMap = HttpQueryOrHeaderMap
export type HttpHeaderMap = HttpQueryOrHeaderMap

--[=[
	@interface FetchParams
	@within Net

	Parameters for sending network requests with `net.request`.

	This is a dictionary that may contain one or more of the following values:

	* `url` - The URL to send a request to. This is always required
	* `method` - The HTTP method verb, such as `"GET"`, `"POST"`, `"PATCH"`, `"PUT"`, or `"DELETE"`. Defaults to `"GET"`
	* `body` - The request body
	* `query` - A table of key-value pairs representing query parameters in the request path
	* `headers` - A table of key-value pairs representing headers
]=]
export type FetchParams = {
	url: string,
	method: HttpMethod?,
	body: (string | buffer)?,
	query: HttpQueryMap?,
	headers: HttpHeaderMap?,
}

--[=[
	@interface FetchResponse
	@within Net

	Response type for sending network requests with `net.request`.

	This is a dictionary containing the following values:

	* `ok` - If the status code is a canonical success status code, meaning within the range 200 -> 299
	* `statusCode` - The status code returned for the request
	* `statusMessage` - The canonical status message for the returned status code, such as `"Not Found"` for status code 404
	* `headers` - A table of key-value pairs representing headers
	* `body` - The request body, or an empty string if one was not given
]=]
export type FetchResponse = {
	ok: boolean,
	statusCode: number,
	statusMessage: string,
	headers: HttpHeaderMap,
	body: string,
}

--[=[
	@interface WebSocket
	@within Net

	A reference to a web socket connection.

	The web socket may be in either an "open" or a "closed" state, changing its current behavior.

	When open:

	* Any function on the socket such as `send`, `next` or `close` can be called without erroring
	* `next` can be called to yield until the next message is received or the socket becomes closed

	When closed:

	* `next` will no longer return any message(s) and instead instantly return nil
	* `send` will throw an error stating that the socket has been closed

	Once the websocket has been closed, `closeCode` will no longer be nil, and will be populated with a close
	code according to the [WebSocket specification](https://www.iana.org/assignments/websocket/websocket.xhtml).
	This will be an integer between 1000 and 4999, where 1000 is the canonical code for normal, error-free closure.
]=]
export type WebSocket = {
	closeCode: number?,
	close: (self: WebSocket, code: number?) -> (),
	send: (self: WebSocket, message: (string | buffer)?, asBinaryMessage: boolean?) -> (),
	next: (self: WebSocket) -> string?,
}

local net = {}

--[=[
	@within Net

	Sends an HTTP request using the given url and / or parameters, and returns a dictionary that describes the response received.

	Only throws an error if a miscellaneous network or I/O error occurs, never for unsuccessful status codes.

	@param config The URL or request config to use
	@return A dictionary representing the response for the request
]=]
function net.request(config: string | FetchParams): FetchResponse
	return nil :: any
end

--[=[
	@within Net
	@tag must_use

	Connects to a web socket at the given URL.

	Throws an error if the server at the given URL does not support
	web sockets, or if a miscellaneous network or I/O error occurs.

	@param url The URL to connect to
	@return A web socket handle
]=]
function net.socket(url: string): WebSocket
	return nil :: any
end

--[=[
	@within Net
	@tag must_use

	Encodes the given value as JSON.

	@param value The value to encode as JSON
	@param pretty If the encoded JSON string should include newlines and spaces. Defaults to false
	@return The encoded JSON string
]=]
function net.jsonEncode(value: any, pretty: boolean?): string
	return nil :: any
end

--[=[
	@within Net
	@tag must_use

	Decodes the given JSON string into a lua value.

	@param encoded The JSON string to decode
	@return The decoded lua value
]=]
function net.jsonDecode(encoded: string): any
	return nil :: any
end

--[=[
	@within Net
	@tag must_use

	Encodes the given string using URL encoding.

	@param s The string to encode
	@param binary If the string should be treated as binary data and/or is not valid utf-8. Defaults to false
	@return The encoded string
]=]
function net.urlEncode(s: string, binary: boolean?): string
	return nil :: any
end

--[=[
	@within Net
	@tag must_use

	Decodes the given string using URL decoding.

	@param s The string to decode
	@param binary If the string should be treated as binary data and/or is not valid utf-8. Defaults to false
	@return The decoded string
]=]
function net.urlDecode(s: string, binary: boolean?): string
	return nil :: any
end

return net

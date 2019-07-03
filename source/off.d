module off;

import vibe.data.json;
import vibe.http.client;

import std.uri : encodeComponent;

Json fetchOFFProduct(string code)
{
	Json ret;
	requestHTTP("https://world.openfoodfacts.org/api/v0/product/" ~ code.encodeComponent ~ ".json",
			null, (scope res) {
		if (res.statusCode != 200)
			throw new Exception("Got invalid server response");
		ret = res.readJson;
	});
	if (ret["status"].get!int != 1)
		throw new Exception(ret["status_verbose"].get!string);
	return ret["product"];
}

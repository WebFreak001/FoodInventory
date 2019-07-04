// Copyright (C) 2019 Jan Jurzitza
// Check LICENSE.md for more

module off;

import vibe.data.json;
import vibe.http.client;

import std.algorithm : all;
import std.ascii : isDigit;
import std.uri : encodeComponent;

Json fetchOFFProduct(string code)
{
	if (!code.all!isDigit)
		throw new Exception("Barcode must consist only of numbers");

	if (code.length != 8 && code.length != 13)
		throw new Exception("Barcode must be EAN-13 or EAN-8");

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

// Copyright (C) 2019 Jan Jurzitza
// Check LICENSE.md for more

module api;

import db;
import off;

import mongoschema;

import vibe.vibe;

import std.algorithm;
import std.array : array;
import std.datetime.systime;

interface IFoodInventory
{
shared:
	Fridge getFridge(string _id);
	Fridge putFridge(string _id, string label = "");

	@path("/fridge/:id/:code")
	void postFridgeItem(string _id, string _code, int expiryDays, double amount = 1, int count = 1);

	@path("/fridge/:id/:item")
	FridgeItem putFridgeItem(string _id, string _item, double useAmount);

	@path("/fridge/:id/:item")
	FridgeItem deleteFridgeItem(string _id, string _item);

	Product getScan(string code);
}

shared class FoodInventory : IFoodInventory
{
	Fridge getFridge(string _id)
	{
		auto fridge = Fridge.tryFindById(_id, Fridge.init);
		if (!fridge.bsonID.valid)
			throw new HTTPStatusException(HTTPStatus.notFound, "Fridge with this ID not found");

		fridge.items = FridgeItem.find(query!FridgeItem.fridge.eq(BsonObjectID.fromString(_id))
				.trashed.ne(true)).array;
		auto now = Clock.currTime;
		fridge.items.sort!((a, b) {
			auto aDays = (a.expiryDate.toSysTime() - now).total!"days";
			auto bDays = (b.expiryDate.toSysTime() - now).total!"days";

			auto dayDifference = aDays - bDays;
			float dayUseDifference = (a.lastUseDate.toSysTime - b.lastUseDate.toSysTime).total!"hours"
				/ 24.0f;

			return dayDifference * 10 + dayUseDifference * dayUseDifference < 0;
		});
		return fridge;
	}

	Fridge putFridge(string _id, string label = "")
	{
		auto fridge = Fridge.tryFindById(_id, Fridge.init);
		if (!fridge.bsonID.valid)
			throw new HTTPStatusException(HTTPStatus.notFound, "Fridge with this ID not found");

		bool change;

		if (label.length)
		{
			fridge.label = label;
			change = true;
		}

		if (change)
			fridge.save();

		return fridge;
	}

	void postFridgeItem(string _id, string _code, int expiryDays, double amount = 1, int count = 1)
	{
		auto fridge = Fridge.tryFindById(_id, Fridge.init);
		if (!fridge.bsonID.valid)
			throw new HTTPStatusException(HTTPStatus.notFound, "Fridge with this ID not found");

		auto product = getScan(_code);
		product.putExpiry(expiryDays);

		FridgeItem item;
		item.product = product.bsonID;
		item.fridge = fridge.bsonID;
		item.code = product.code;
		item.name = product.name;
		item.image = product.image;
		item.expiryDate = SchemaDate.fromSysTime(Clock.currTime + expiryDays.days);
		item.stored = amount;

		foreach (i; 0 .. min(count, 10))
		{
			item.bsonID = BsonObjectID.generate;
			item.save();
		}
	}

	FridgeItem putFridgeItem(string _id, string _item, double useAmount)
	{
		auto item = FridgeItem.tryFindById(_item, FridgeItem.init);
		if (item.fridge != BsonObjectID.fromString(_id) || !item.bsonID.valid)
			throw new HTTPStatusException(HTTPStatus.notFound,
					"Item with this ID and this fridge not found");

		item.use(useAmount);
		item.save();

		return item;
	}

	FridgeItem deleteFridgeItem(string _id, string _item)
	{
		auto item = FridgeItem.tryFindById(_item, FridgeItem.init);
		if (item.fridge != BsonObjectID.fromString(_id) || !item.bsonID.valid)
			throw new HTTPStatusException(HTTPStatus.notFound,
					"Item with this ID and this fridge not found");

		item.stored = 0;
		item.trashed = true;
		item.save();

		return item;
	}

	Product getScan(string code)
	{
		if (!code.length)
			throw new HTTPStatusException(HTTPStatus.badRequest, "need to specify a value for code");

		Product p = Product.tryFindOne(query!Product.code.eq(code), Product.init);
		if (!p.code.length)
		{
			Json product = fetchOFFProduct(code);

			p = Product.init;
			p.code = code;
			p.name = product["product_name"].get!string;
			p.image = product["image_front_url"].get!string;
			const categories = product["categories_hierarchy"].deserializeJson!(string[]);
			if (categories.length)
				p.mainCategory = categories[$ - 1];
			p.product = product;

			auto existing = Product.aggregate.match(query!Product.mainCategory.eq(p.mainCategory)
					.numExpirySamples.gte(1)).groupAll([
					"count": ["$sum": Bson(1)],
					"expires": ["$avg": Bson("$averageExpiryDays")]
					]).run.get!(Bson[]);
			logInfo("aggregate: %s", existing);
			if (existing.length == 1 && existing[0]["count"].get!int > 0)
			{
				p.averageExpiryDays = existing[0]["expires"].to!double;
				p.numExpirySamples = 1; // this is still a different product, so just suggest existing averages
			}

			p.save();
		}
		return p;
	}
}

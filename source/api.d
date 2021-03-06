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
	@path("/fridge")
	Fridge postFridge(string label);

	/// Returns fridges based on a comma separated id list
	@path("/fridges")
	Fridge[] getFridges(string ids);

	@path("/fridge/:id")
	Fridge getFridge(string _id);

	@path("/fridge/:id")
	Fridge putFridge(string _id, string label = "");

	@path("/fridge/:id/:code")
	void postFridgeItem(string _id, string _code, int expiryDays, double amount = 1, int count = 1);

	@path("/fridge/:id/:item")
	FridgeItem putFridgeItem(string _id, string _item, double amount);

	@path("/fridge/:id/:item")
	FridgeItem deleteFridgeItem(string _id, string _item);

	Product getScan(string code, bool force = false);
}

shared class FoodInventory : IFoodInventory
{
	Fridge postFridge(string label)
	{
		Fridge fridge;
		fridge.label = label;
		fridge.save();
		return fridge;
	}

	Fridge getFridge(string _id)
	{
		auto fridge = Fridge.tryFindById(_id, Fridge.init);
		if (!fridge.bsonID.valid)
			throw new HTTPStatusException(HTTPStatus.notFound, "Fridge with this ID not found");

		fridge.items = FridgeItem.find(query!FridgeItem.fridge.eq(BsonObjectID.fromString(_id))
				.trashed.ne(true)).array;
		// logInfo("Items:\n%(%s\n%)", fridge.items.map!(a => format!"expires=%s, used=%s"));
		auto now = Clock.currTime;
		fridge.items.sort!((a, b) => a.rank(now) < b.rank(now));
		return fridge;
	}

	Fridge[] getFridges(string ids)
	{
		return Fridge.find([
				"_id": ["$in": ids.splitter(',').map!(BsonObjectID.fromString).array]
				]);
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

		fridge.lastUse = SchemaDate.now;
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

		Fridge.didUse(fridge.bsonID);

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

	FridgeItem putFridgeItem(string _id, string _item, double amount)
	{
		auto item = FridgeItem.tryFindById(_item, FridgeItem.init);
		if (item.fridge != BsonObjectID.fromString(_id) || !item.bsonID.valid)
			throw new HTTPStatusException(HTTPStatus.notFound,
					"Item with this ID and this fridge not found");

		Fridge.didUse(item.fridge);

		item.useTo(amount);
		item.save();

		return item;
	}

	FridgeItem deleteFridgeItem(string _id, string _item)
	{
		auto item = FridgeItem.tryFindById(_item, FridgeItem.init);
		if (item.fridge != BsonObjectID.fromString(_id) || !item.bsonID.valid)
			throw new HTTPStatusException(HTTPStatus.notFound,
					"Item with this ID and this fridge not found");

		Fridge.didUse(item.fridge);

		item.stored = 0;
		item.trashed = true;
		item.save();

		return item;
	}

	Product getScan(string code, bool force = false)
	{
		if (!code.length)
			throw new HTTPStatusException(HTTPStatus.badRequest, "need to specify a value for code");

		Product p = Product.tryFindOne(query!Product.code.eq(code), Product.init);
		if (force || !p.code.length || p.needsRenew)
		{
			Json product;
			try
			{
				product = fetchOFFProduct(code);
			}
			catch (Exception e)
			{
				if (p.code.length && !force)
				{
					logInfo("Failed updating cache for product %s", p.code);
					return p;
				}
				else
					throw e;
			}

			p = Product.init;
			p.code = code;
			p.name = product["product_name"].get!string;
			if ("image_front_url" in product)
				p.image = product["image_front_url"].get!string;

			if ("categories_hierarchy" in product)
			{
				const categories = product["categories_hierarchy"].deserializeJson!(string[]);
				if (categories.length)
					p.mainCategory = categories[$ - 1];
			}
			p.product = product;

			if (p.mainCategory.length && p.numExpirySamples == 0)
			{
				auto existing = Product.aggregate.match(query!Product.mainCategory.eq(p.mainCategory)
						.numExpirySamples.gte(1)).groupAll([
						"count": ["$sum": Bson(1)],
						"expires": ["$avg": Bson("$averageExpiryDays")]
						]).run.get!(Bson[]);
				if (existing.length == 1 && existing[0]["count"].get!int > 0)
				{
					p.averageExpiryDays = existing[0]["expires"].to!double;
					p.numExpirySamples = 1; // this is still a different product, so just suggest existing averages
				}
			}

			p.save();
		}
		return p;
	}
}

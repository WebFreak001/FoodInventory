// Copyright (C) 2019 Jan Jurzitza
// Check LICENSE.md for more

module db;

import vibe.db.mongo.collection;
import vibe.data.bson;

import core.time;

import std.datetime.systime;

import mongoschema;

struct Product
{
	@mongoUnique string code;
	string name;
	string image;
	string mainCategory;
	double averageExpiryDays = 0;
	int numExpirySamples;
	string api = "v0";
	Bson product;
	SchemaDate checkDate = SchemaDate.now;

	mixin MongoSchema;

	void putExpiry(int days)
	{
		if (days <= 0 || (days >= averageExpiryDays * 2 && numExpirySamples > 3)
				|| numExpirySamples >= 1000)
			return;

		averageExpiryDays = (averageExpiryDays * numExpirySamples + days) / (++numExpirySamples);
		Product.collection.update(["_id": bsonID], [
				"$set": [
					"averageExpiryDays": Bson(averageExpiryDays),
					"numExpirySamples": Bson(numExpirySamples)
				]
				]);
	}

	bool needsRenew() @property const
	{
		return checkDate.time == -1 || Clock.currTime - checkDate.toSysTime > 7.days;
	}
}

struct Fridge
{
	string label;
	SchemaDate lastUse = SchemaDate.now;
	@schemaIgnore FridgeItem[] items;

	mixin MongoSchema;

	static void didUse(BsonObjectID id)
	{
		this.collection.update(["_id": id], [
				"$set": ["lastUse": SchemaDate.toBson(SchemaDate.now)]
				]);
	}
}

struct FridgeItem
{
	@mongoForceIndex BsonObjectID fridge;
	BsonObjectID product;
	string code;
	string name;
	string image;
	SchemaDate storeDate = SchemaDate.now;
	SchemaDate lastUseDate = SchemaDate.now;
	SchemaDate expiryDate;
	double stored = 1;
	int timesUsed = 0;
	bool trashed = false;

	mixin MongoSchema;

	void use(double amount)
	{
		stored -= amount;
		timesUsed++;
		lastUseDate = SchemaDate.now;
	}
}

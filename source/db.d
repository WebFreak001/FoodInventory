module db;

import vibe.db.mongo.collection;
import vibe.data.bson;

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

	mixin MongoSchema;
}

struct Fridge
{
	string label;
	@schemaIgnore FridgeItem[] items;

	mixin MongoSchema;
}

struct FridgeItem
{
	@mongoForceIndex BsonObjectID fridge;
	BsonObjectID product;
	string code;
	string name;
	string image;
	SchemaDate storeDate;
	SchemaDate lastUseDate;
	SchemaDate expiryDate;
	double stored = 1;
	int timesUsed = 0;

	mixin MongoSchema;

	void use(double amount)
	{
		stored -= amount;
		timesUsed++;
		lastUseDate = SchemaDate.now;
	}
}

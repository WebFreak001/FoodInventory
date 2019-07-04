// Copyright (C) 2019 Jan Jurzitza
// Check LICENSE.md for more

import api;
import db;
import mongoschema;
import vibe.vibe;

shared FoodInventory fi;
void main()
{
	auto db = connectMongoDB("mongodb://127.0.0.1").getDatabase("foodinventory");
	db["products"].register!Product;
	db["fridges"].register!Fridge;
	db["items"].register!FridgeItem;

	auto settings = new HTTPServerSettings;
	settings.port = 3000;
	settings.bindAddresses = ["::1", "127.0.0.1"];

	auto router = new URLRouter;
	router.get("*", serveStaticFiles("public"));
	router.get("/", &index);
	router.get("/fridge", &getFridge);
	router.post("/fridge", &postFridge);
	router.registerRestInterface(fi = new FoodInventory, "/api");
	listenHTTP(settings, router);

	runApplication();
}

void index(HTTPServerRequest req, HTTPServerResponse res)
{
	res.render!"index.dt";
}

void getFridge(HTTPServerRequest req, HTTPServerResponse res)
{
	auto fridge = fi.getFridge(req.query.get("id"));
	res.render!("fridge.dt", fridge);
}

void postFridge(HTTPServerRequest req, HTTPServerResponse res)
{
	Fridge fridge;
	fridge.label = "Unnamed Fridge";
	fridge.save();
	res.redirect("/fridge?id=" ~ fridge.bsonID.toString);
}

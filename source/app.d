import api;
import db;
import mongoschema;
import vibe.vibe;

void main()
{
	auto db = connectMongoDB("mongodb://127.0.0.1/foodinventory");
	db["products"].register!Product;
	db["fridges"].register!Fridge;
	db["items"].register!FridgeItem;

	auto settings = new HTTPServerSettings;
	settings.port = 3000;
	settings.bindAddresses = ["::1", "127.0.0.1"];

	auto router = new URLRouter;
	router.get("/", &index);
	router.registerRestInterface(new FoodInventory);
	listenHTTP(settings, router);

	runApplication();
}

void index(HTTPServerRequest req, HTTPServerResponse res)
{
	res.writeBody("https://github.com/WebFreak001/FoodInventory");
}

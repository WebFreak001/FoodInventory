module api;

import db;
import off;

import mongoschema;

import vibe.vibe;

interface IFoodInventory
{
	Fridge getFridge(string _id);
	Fridge putFridge(string _id, string name = "");

	Product getScan(string code);
}

class FoodInventory : IFoodInventory
{
	Fridge getFridge(string _id)
	{
	}

	Fridge putFridge(string _id, string name = "")
	{
	}

	Product getScan(string code)
	{
		if (!p.code.length)
			throw new HTTPStatusException(HTTPStatus.badRequest, "need to specify a value for code");

		Product p = Product.tryFindOne(query!Product.code.eq(code), Product.init);
		if (!p.code.length)
		{
			Json product = fetchOFFProduct(code);

			p = Product.init;
			p.code = code;
			p.name = product["product_name"].get!string;
			p.image = product["image_front_url"].get!string;
			p.mainCategory = product["categories_hierarchy"].get!(string[])[$ - 1];
			p.product = product;
			p.save();
		}
		return p;
	}
}

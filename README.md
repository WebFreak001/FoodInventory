# FoodInventory

A simple fridge manager to keep track of all items in the fridge.

Eventually it's supposed to be able to run on an Android Smartphone or on a small computer with a scanner next to the fridge to scan items.

It is using OpenFoodFacts as a database for food entries and a local MongoDB instance to cache all products and store average expiry dates.

Usage:
for every product being taken out or put into the fridge you scan the EAN-13/EAN-8 code (barcode) on the product. Then you either click add to register a new product (just purchased) in the fridge or to use or throw away existing products from your fridge. Via the web interface you have to enter the ID when clicking the scan button, a hardware scanner can be used to automate this. On Android it's planned to have it work using the Camera.

The app displays the stored products sorted by expiry date and last use date. Basically it is trying to minimize the time a product stays unused in the fridge while also making products which are soon-to-expire ranked further up.

![Screenshot of early web interface of the fridge](https://wfr.moe/f6gAgs.png)

Currently to register a fridge, open the developer tools, change the form method to POST and click submit to generate a new fridge (this is only needed once, and then the ID in the URL can be used to access the fridge again)

TODO:
- make an Android app
- improve the web app / remake it properly
- show dialog when a product is not found to make the user add it to the database
- refine sorting to more accurately sort unused products further at the top to make them used, also take remaining amount into account
- make a proper admin interface and web service for others to use

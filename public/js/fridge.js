var dates = document.getElementsByClassName("date");
for (var i = 0; i < dates.length; i++) {
	var date = dates[i];
	var d = new Date(date.textContent);
	if (date.classList.contains("relative"))
	{
		var dt = dateDiff(d, new Date());
		if (dt < -1)
			date.textContent = (-dt) + " days ago";
		else if (dt == -1)
			date.textContent = "yesterday";
		else if (dt == 0)
			date.textContent = "today";
		else if (dt == 1)
			date.textContent = "tomorrow";
		if (dt > 1)
			date.textContent = "in " + dt + " days";
	}
	else
		date.textContent = d.toLocaleDateString();
}
var datetime = document.getElementsByClassName("datetime");
for (var i = 0; i < datetime.length; i++) {
	var date = datetime[i];
	date.textContent = new Date(date.textContent).toLocaleString();
}

function addItem() {
	var item = prompt("Enter item ID");
	if (!item)
		return;

	var xhr = new XMLHttpRequest();
	xhr.open("GET", "/api/scan?code=" + encodeURIComponent(item));

	xhr.onloadend = function () {
		if (xhr.status == 200) {
			var product = JSON.parse(xhr.responseText);

			var dialog = document.getElementById("picker");
			dialog.querySelector(".name").textContent = product.name;
			dialog.querySelector(".image").src = product.image;
			dialog.querySelector(".count").value = 1;
			dialog.querySelector(".remaining").value = 1;
			var expiry = new Date();
			expiry.setDate(expiry.getDate() + product.averageExpiryDays);
			setupDatePicker(dialog.querySelector(".datepicker"), expiry);

			dialog.querySelector(".cancel").onclick = function () {
				dialog.style.display = "none";
			};

			dialog.querySelector(".save").onclick = function () {
				dialog.style.display = "none";
				saveItem(product, parseInt(dialog.querySelector(".daysremaining").textContent), parseFloat(dialog.querySelector(".remaining").value), parseInt(dialog.querySelector(".count").value));
			};

			dialog.style.display = "";
		} else {
			alert(JSON.parse(xhr.responseText).statusMessage);
		}
	};

	xhr.send();
}

function saveItem(product, days, amount, count) {
	var xhr = new XMLHttpRequest();
	xhr.open("POST", "/api/fridge/" + fridgeID + "/" + product.code);
	var data = {
		expiryDays: days,
		amount: amount || 1,
		count: count || 1
	};
	xhr.onloadend = function () {
		if (xhr.status == 200)
			window.location.reload();
		else
			alert(JSON.parse(xhr.responseText).statusMessage);
	};

	xhr.setRequestHeader("Content-Type", "application/json");
	xhr.send(JSON.stringify(data));
}

/**
 * @param {HTMLElement} datepicker 
 * @param {Date} expiry 
 */
function setupDatePicker(datepicker, expiry) {
	var exprs = datepicker.querySelectorAll(".expr");
	var ref = new Date();

	var year = datepicker.querySelector(".year");
	var month = datepicker.querySelector(".month");
	var day = datepicker.querySelector(".day");

	function update() {
		year.textContent = expiry.getFullYear();
		month.textContent = expiry.getMonth() + 1;
		day.textContent = expiry.getDate();
		datepicker.setAttribute("data-value", expiry.getTime());
		var days = dateDiff(expiry, ref);
		datepicker.nextElementSibling.querySelector(".daysremaining").textContent = days;
	}

	update();

	for (var i = 0; i < exprs.length; i++) {
		exprs[i].onclick = function () {
			var amount = parseInt(this.getAttribute("data-amount"));
			switch (this.getAttribute("data-type")) {
				case "year":
					expiry.setFullYear(expiry.getFullYear() + amount);
					break;
				case "month":
					expiry.setMonth(expiry.getMonth() + amount);
					break;
				case "day":
					expiry.setDate(expiry.getDate() + amount);
					break;
			}
			update();
		};
	}
}

function dateDiff(a, b) {
	return Math.round((a.getTime() - b.getTime()) / 1000 / 60 / 60 / 24);
}

var dates = document.getElementsByClassName("date");
for (var i = 0; i < dates.length; i++) {
	var date = dates[i];
	var d = new Date(date.textContent);
	if (date.classList.contains("relative")) {
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

	scanItem(item);
}

var scanPreview = document.getElementById("scaninput");
document.addEventListener("keydown", function (e) {
	if (e.key == "Backspace") {
		e.preventDefault();
		scanPreview.textContent = scanPreview.textContent.slice(0, -1);
	} else if (e.key == "Escape") {
		e.preventDefault();
		scanPreview.textContent = "";
	} else if (e.key == "Enter") {
		e.preventDefault();
		var code = scanPreview.textContent;
		scanPreview.textContent = "";
		scanItem(code);
	} else if (e.key >= '0' && e.key <= '9') {
		scanPreview.textContent = scanPreview.textContent + e.key;
	}
});

function scanItem(item) {
	var existing = document.querySelectorAll("body > .items > .item[data-code=\"" + item + "\"]");
	if (existing.length == 0) {
		doAdd(item);
	} else {
		showExistingDialog(item, existing[0].querySelector(".name").textContent, existing);
	}
}

function doAdd(item) {
	var xhr = new XMLHttpRequest();
	xhr.open("GET", "/api/scan?code=" + encodeURIComponent(item));

	xhr.onloadend = function () {
		if (xhr.status == 200) {
			var product = JSON.parse(xhr.responseText);
			showAddDialog(product);
		} else {
			alert(JSON.parse(xhr.responseText).statusMessage);
		}
	};

	xhr.send();
}

function showExistingDialog(item, name, src) {
	var dialog = document.getElementById("addmore");
	var details = dialog.querySelector(".details");
	while (details.hasChildNodes())
		details.removeChild(details.lastChild);
	dialog.querySelector(".name").textContent = name;

	var items = [];
	var index = 0;
	var changedAmount = false;

	function close(force) {
		if (!force && changedAmount) {
			didUseItem(items[index].getAttribute("data-id"), parseFloat(items[index].querySelector(".remaining").value));
		} else {
			while (details.hasChildNodes())
				details.removeChild(details.lastChild);
			dialog.style.display = "none";
		}
	}

	var imageSource;
	for (var i = 0; i < src.length; i++) {
		var copy = items[i] = src[i].cloneNode(true);
		copy.querySelector(".image").style.display = "none";
		copy.querySelector(".name").style.display = "none";
		imageSource = copy.querySelector(".image img").src;
		copy.querySelector(".actions").style.display = "none";
		copy.style.display = index == i ? "" : "none";

		var remaining = document.createElement("label");
		var label = document.createElement("span");
		label.textContent = "Remaining";
		var input = document.createElement("input");
		input.classList.add("remaining");
		input.type = "range";
		input.min = 0;
		input.max = 1;
		input.step = 0.01;
		input.value = parseFloat(copy.getAttribute("data-stored"));
		input.onchange = function () {
			changedAmount = true;
		};

		remaining.appendChild(label);
		remaining.appendChild(input);
		copy.appendChild(remaining);

		details.appendChild(copy);
	}

	dialog.querySelector(".image").src = imageSource;

	function updateVisible() {
		for (var i = 0; i < items.length; i++) {
			items[i].style.display = index == i ? "" : "none";
		}
	}

	dialog.querySelector(".scroll .up").onclick = function () {
		index = (index + items.length - 1) % items.length;
		updateVisible();
	};

	dialog.querySelector(".scroll .down").onclick = function () {
		index = (index + 1) % items.length;
		updateVisible();
	};

	dialog.querySelector(".buttons .addanother").onclick = function () {
		close(true);
		doAdd(item);
	};

	dialog.querySelector(".buttons .trash").onclick = function () {
		close(true);
		trashItem(items[index]);
	};

	dialog.querySelector(".close").onclick = function () {
		close();
	};

	dialog.style.display = "";
}

function showAddDialog(product) {
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

function trashItem(item) {
	var name = item.querySelector(".name").textContent;
	if (!confirm("Do you really want to trash one " + name + "?"))
		return;

	var id = item.getAttribute("data-id");

	var xhr = new XMLHttpRequest();
	xhr.open("DELETE", "/api/fridge/" + fridgeID + "/" + id);
	xhr.onloadend = function () {
		if (xhr.status == 200)
			window.location.reload();
		else
			alert(JSON.parse(xhr.responseText).statusMessage);
	};

	xhr.send();
}

function didUseItem(id, amount) {
	var data = {
		amount: parseFloat(amount)
	};

	var xhr = new XMLHttpRequest();
	xhr.open("PUT", "/api/fridge/" + fridgeID + "/" + id);
	xhr.onloadend = function () {
		if (xhr.status == 200)
			window.location.reload();
		else
			alert(JSON.parse(xhr.responseText).statusMessage);
	};

	xhr.setRequestHeader("Content-Type", "application/json");
	xhr.send(JSON.stringify(data));
}

function useItem(item) {
	var dialog = document.getElementById("usage");
	var remaining = parseFloat(item.getAttribute("data-stored"));
	var id = item.getAttribute("data-id");
	dialog.querySelector(".name").textContent = item.querySelector(".name").textContent;
	dialog.querySelector(".remaining").value = remaining;

	dialog.querySelector(".cancel").onclick = function () {
		dialog.style.display = "none";
	};

	dialog.querySelector(".save").onclick = function () {
		dialog.style.display = "none";

		didUseItem(id, dialog.querySelector(".remaining").value);
	};

	dialog.style.display = "";
}

"use strict";

const form = document.getElementById("demo");
const wallet = document.getElementById("wallet");
const postage = document.getElementById("postage");
const reserve = document.getElementById("reserve");
const result = document.getElementById("result");

function render() {
  if (!form.checkValidity()) {
    result.textContent = "Enter a valid balance and postage.";
    return;
  }
  const copper = Math.round(wallet.valueAsNumber * 10000);
  const surplus = copper - postage.valueAsNumber - reserve.valueAsNumber * 10000;
  if (surplus <= 0) {
    result.textContent = "No transfer. The alt keeps its balance.";
    return;
  }
  const gold = Math.floor(surplus / 10000);
  const silver = Math.floor(surplus / 100) % 100;
  result.textContent = gold + "g " + silver + "s " + (surplus % 100) + "c";
}

form.addEventListener("submit", (event) => {
  event.preventDefault();
  render();
});
form.addEventListener("input", render);

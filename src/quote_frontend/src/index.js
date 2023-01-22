import { AuthClient } from "@dfinity/auth-client";
import { Actor } from "@dfinity/agent";
import { quote_backend } from "../../declarations/quote_backend";
import { ok } from "assert";

let quoteOfTheQuotes;
let authClient = null;

//Dom element
const domQuoteOfTheQuotes = document.getElementById("quoteOfTheQuotes");
//drawer elements 
const domDrawer = document.getElementById("drawerQuotes");
const domRadioDrawer = document.getElementById("radioDrawerQuotes")
const domNbQuotes = document.getElementById("nbQuotes");
const domQuotesContent = document.getElementById("drawerQuotesContent");
//dialog elements
const domTextSubmitAuthor = document.getElementById("author");
const domTextAreaSubmitQuote = document.getElementById("quote");
const domErrorTextAreaQuote = document.getElementById("error-quote");
const domSubmitQuote = document.getElementById("submitQuote");

const domWhoIsConnected = document.getElementById("whoIsConnected");


//1. First on load triggered
document.addEventListener("DOMContentLoaded", function(event) {
  requestQuoteOfTheQuotes();
});
//2. Last on load triggered function. Not used for the moment
//window.addEventListener('load', function() {});

//3. Rendering and html functions
function renderQuoteOfTheQuotes(quote) {
  domQuoteOfTheQuotes.removeAttribute("aria-busy");
  domQuoteOfTheQuotes.innerHTML = `<div style="color: gray; font-size: smaller;">` + timeDifferenceToText(Number(quote.date)) + `</div>`
     + `<p>`+ quote.quote.replace(/\r?\n/g, "<br />") + `</p>`
     + `<div class="autor">` + quote.authorName + `</div>`;
};
function getHtmlSingleQuote(index, quote) {
  return `<div class="quote" id="quote-` + index + `">
    <img class="circle" src="logo.png" alt="">
      <div class="bubble boxed">
        <div class="bubble-header">
          <div class="bubble-button">
              <span>
                <i class="fa-solid fa-heart data-quote-index" data-quote-index="` + index + `" data-quote-choice-accepted="true" role="link"></i>`
                 + quote.acceptedVotingPower + 
              `</span>
              <span>
                <i class="fa-solid fa-poo data-quote-index" data-quote-index="` + index + `" data-quote-choice-rejected="true" role="link"></i>`
                 + quote.rejectedVotingPower + 
              `</span>
          </div>
          <span></span>
          <span>` + timeDifferenceToText(Number(quote.date)) + `</span>
        </div>
        <div class="bubble-quote">
          <p>` + quote.quote.replace(/\r?\n/g, "<br />") + `</p>
          <div class="autor">` + (quote.authorName?quote.authorName:"") + `</div>
        </div>
      </div>
  </div>`;
};

async function requestQuoteOfTheQuotes() {
  let quote = await quote_backend.get_quoteOfTheQuotes();
  renderQuoteOfTheQuotes(quote);
}

async function init() {
  authClient = await AuthClient.create();
  let whoIsConnected = await quote_backend.whoIsConnected();
  onAuthLoadInterface(whoIsConnected);
};

domSubmitQuote.addEventListener("click", async (e) => {
  e.preventDefault();

  //1. check min-length frontend, not only backend
  if(domTextAreaSubmitQuote.value.length < 10) {
    domTextAreaSubmitQuote.setAttribute("aria-invalid","true");
    domErrorTextAreaQuote.innerHTML = domTextAreaSubmitQuote.value;
  } else {
    //2. Submit
    async function send() {
      //disable the submit button
      domSubmitQuote.setAttribute("aria-busy","true");
      domSubmitQuote.setAttribute("disabled", "disabled");
      domSubmitQuote.classList.add("contrast");
      let response = await quote_backend.submit_proposal(domTextAreaSubmitQuote.value, [domTextSubmitAuthor.value]);
      
      
      //enable the submit button
      domSubmitQuote.removeAttribute("aria-busy");
      domSubmitQuote.removeAttribute("disabled");
      domSubmitQuote.classList.remove("contrast");

      //open the Drawer and hide the modal
      domRadioDrawer.click();
    }
    send();
  }
});

domRadioDrawer.addEventListener("change", async (e) => {
  //1. Load query first. It's fast, don't need to wait
  const nbquotes = await quote_backend.size();
  const quotes = await quote_backend.get_all_proposals();

  domNbQuotes.innerHTML = nbquotes.toString();

  //update list of all Quotes
  let s = "";
  quotes.forEach((quote, index) => {
    s += getHtmlSingleQuote(index, quote);
  });
  domQuotesContent.innerHTML = s;
  return false;
});

//VOTE
document.body.addEventListener("click", async (e) => {
  let indexItem = e.target.getAttribute("data-quote-index")
  if(indexItem >= 0 && indexItem != null && indexItem != undefined) {
    e.preventDefault();
    let domItem = e.target;
    let response;

    //replace the emoji - no multi click
    let parentNode = domItem.parentNode;
    let domLoading = document.createElement("i");
    let hasAttributeChoiceRejected = domItem.hasAttribute("data-quote-choice-rejected");
    let hasAttributeChoiceAccepted = domItem.hasAttribute("data-quote-choice-accepted");
    domLoading.setAttribute("aria-busy","true");
    parentNode.replaceChild(domLoading,domItem);

    if(hasAttributeChoiceAccepted) {
      response = await quote_backend.voteAccepted(parseInt(indexItem));
    } else if(hasAttributeChoiceRejected) {
      response = await quote_backend.voteRejected(parseInt(indexItem));
    }

    if(response.err) {
      //TO DO : Show an error message
    }

    //Change the interface depending the response
    if(response.ok) {
      //if number at begin, update them
      if(RegExp("^[0-9]").test(response.ok)) {
        //first number is total accepted, second number is total rejected
        let value = response.ok.split("-");
        if(hasAttributeChoiceAccepted) {
          parentNode.innerHTML = value[0];
          parentNode.insertBefore(domItem, parentNode.firstChild);
        } else if(hasAttributeChoiceRejected) {
          parentNode.innerHTML = value[1];
          parentNode.insertBefore(domItem, parentNode.firstChild);
        }
      } else {
        //if a string is at the begin, was definitively accepted or rejected => Delete item
        document.getElementById("quote-" + indexItem).remove();
        //TO DO : Show an delete message
      }
    }
  } 
});


//LOGIN
function onAuthLoadInterface(whoIsConnected) {
  //top right of the screen
  domWhoIsConnected.innerHTML = whoIsConnected.principal;

  //update login zone if authenticated or not
  // + By pass auth issues localy, no special security issue
  switch(whoIsConnected.isAuth || window.location.href == "http://localhost:8080/") {
    case(true) :
      domDrawer.classList.add("authenticated");
      break;
    case(false) :
      domDrawer.classList.remove("authenticated");
      break;
  };
}
function handleSuccessLogin() {
  const principalId = authClient.getIdentity().getPrincipal().toText();
  onAuthLoadInterface({isAuth : true, principal : principalId});

  Actor.agentOf(quote_backend).replaceIdentity(
    authClient.getIdentity()
  );
}
document.getElementById("btnLogin").addEventListener("click", async (e) => {
  e.preventDefault();
  
  if (!authClient) throw new Error("AuthClient not initialized");
  authClient.login({
    onSuccess: handleSuccessLogin,
  });

  return false;
});


/*
 * Drawer
 *
 */
function onDrawerToogleChange(el, event) {
	if(el.id=="radioCloseDrawerMenu") {
		document.body.style.overflow = 'auto';
	} else {
		document.body.style.overflow = 'hidden';
	}
}

let aDrawerToggle = document.querySelectorAll('input[name="drawer-toggle"]');
for(let i=0;i<aDrawerToggle.length; i++) {
	aDrawerToggle[i].addEventListener('change', event => {
		onDrawerToogleChange(aDrawerToggle[i], event);
	});
}

/*
 * HELPERS
 *
 */

function timeDifferenceToText(previous, current=Date.now()) {
  if(previous > Number.MAX_SAFE_INTEGER) {
    //the date was stored as a BigInt -> motoko
    previous = Math.floor(previous / 1_000_000);
  }
  var msPerMinute = 60 * 1000;
  var msPerHour = msPerMinute * 60;
  var msPerDay = msPerHour * 24;
  var msPerMonth = msPerDay * 30;
  var msPerYear = msPerDay * 365;

  var elapsed = current - previous;

  if (elapsed < msPerMinute) { return Math.round(elapsed/1000) + ' seconds ago'; }
  else if (elapsed < msPerHour) { return Math.round(elapsed/msPerMinute) + ' minutes ago'; }
  else if (elapsed < msPerDay ) { return Math.round(elapsed/msPerHour ) + ' hours ago'; }
  else if (elapsed < msPerMonth) { return Math.round(elapsed/msPerDay) + ' days ago'; }
  else if (elapsed < msPerYear) { return + Math.round(elapsed/msPerMonth) + ' months ago'; }
  else { return Math.round(elapsed/msPerYear ) + ' years ago'; }
}

init();
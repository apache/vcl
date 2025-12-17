var newtokenid = 0;

function initTokens() {
	RPCwrapper({continuation: dojo.byId('tokenlistcont').value}, tokenListCB, 1);
}

function tokenListCB(data, ioArgs) {
	var keys = Object.keys(data.items.tokens);
	var len = keys.length
	for(var i = 0; i < len; i++) {
		console.log(data.items.tokens[keys[i]]);
		var item = data.items.tokens[keys[i]];
		addTokenToList(item.id, item.name, item.expires);
	}
	checkTokenListLength();
}

function createToken() {
	dojo.addClass('tokenerrmsg', 'hidden');
	var data = {
		name: dijit.byId('tokenname').value,
		continuation: dojo.byId('addtokencont').value
	};
	dijit.byId('addtokenbtn').set('disabled', true);
	RPCwrapper(data, createTokenCB, 1);
}

function createTokenCB(data, ioArgs) {
	if(data.items.status == 'invalidname') {
		dijit.byId('tokenname').isValid();
		dijit.byId('addtokenbtn').set('disabled', false);
		return;
	}
	if(data.items.status == 'duplicatename') {
		dojo.removeClass('tokenerrmsg', 'hidden');
		dojo.byId('tokenerrmsg').innerHTML = data.items.msg;
		dijit.byId('addtokenbtn').set('disabled', false);
		return;
	}
	newtokenid = data.items.id;
	addTokenToList(data.items.id, data.items.name, data.items.expires);
	dojo.removeClass('createdtokendiv', 'hidden');
	dojo.byId('newtoken').innerHTML = data.items.value;
	dojo.byId('newtokena').onclick = function() {navigator.clipboard.writeText(data.items.value)};
	dijit.byId('tokenname').reset();
	dijit.byId('addtokenbtn').set('disabled', false);
}

function checkTokenListLength() {
	if(dojo.byId('tokenlist').childNodes.length <= 2) {
		dojo.addClass('tokenlist', 'hidden');
		dojo.removeClass('notokens', 'hidden');
	}
	else {
		dojo.removeClass('tokenlist', 'hidden');
		dojo.addClass('notokens', 'hidden');
	}
}

function addTokenToList(id, name, expires) {
	var ce = document.createElement.bind(document);
	var rowspan = ce('span');
	rowspan.setAttribute('id', id + 'span');
	rowspan.setAttribute('class', 'tokenrow');
	var txtspan = ce('span');
	rowspan.appendChild(txtspan);
	var namespan = ce('span');
	namespan.setAttribute('class', 'tokenname');
	namespan.innerHTML = name;
	txtspan.appendChild(namespan);
	txtspan.appendChild(ce('br'));
	var expspan = ce('span');
	expspan.setAttribute('class', 'tokenexp');
	expspan.innerHTML = 'Expires: ' + expires;
	txtspan.appendChild(expspan);
	var btn = new dijit.form.Button({
		id: id + 'delbtn',
		label: _('Delete'),
		onClick: function() {
			deleteToken(id);
		}
	}, document.createElement('div'));
	rowspan.appendChild(btn.domNode);
	dojo.byId('tokenlist').appendChild(rowspan);
	checkTokenListLength();
}

function deleteToken(id) {
	dijit.byId(id + 'delbtn').set('disabled', true);
	var data = {
		tokenid: id,
		continuation: dojo.byId('deletetokencont').value
	};
	RPCwrapper(data, deleteTokenCB, 1);
}

function deleteTokenCB(data, ioArgs) {
	if(data.items.status == 'failed') {
		dijit.byId(data.items.id + 'delbtn').set('disabled', false);
		alert(data.items.msg);
		return;
	}
	var id = data.items.id;
	dijit.byId(id + 'delbtn').destroy();
	dojo.destroy(id + 'span');
	if(newtokenid == data.items.id) {
		dojo.byId('createdtokendiv').innerHTML = '';
		dojo.addClass('createdtokendiv', 'hidden');
	}
	checkTokenListLength();
}

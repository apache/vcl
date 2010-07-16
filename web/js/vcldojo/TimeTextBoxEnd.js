if(! dojo._hasResource["vcldojo.TimeTextBoxEnd"]) {
dojo._hasResource["vcldojo.TimeTextBoxEnd"] = true;
dojo.provide("vcldojo.TimeTextBoxEnd");
dojo.declare(
	"vcldojo.TimeTextBoxEnd",
	dijit.form.TimeTextBox,
	{
		startid: '',
		invalidMessage: 'This must be a valid time that is greater than the start time',
		isValid: function(isFocused) {
			if(dijit.byId(this.startid)) {
				var start = dijit.byId(this.startid).value;
				if(start !== null && this.value !== null && start >= this.value)
					return false;
			}
			return this.inherited(arguments);
		}
	}
);
}

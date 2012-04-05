/*
* Licensed to the Apache Software Foundation (ASF) under one or more
* contributor license agreements.  See the NOTICE file distributed with
* this work for additional information regarding copyright ownership.
* The ASF licenses this file to You under the Apache License, Version 2.0
* (the "License"); you may not use this file except in compliance with
* the License.  You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/
dojo.provide("vcldojo.HoverTooltip");

dojo.declare(
	"vcldojo._MasterTooltip",
	dijit._MasterTooltip,
	{
		tooltipobj: '',
		_saveAroundNode: '',
		templateString: dojo.cache("dijit", "templates/Tooltip.html", "<div class=\"dijitTooltip dijitTooltipLeft\" id=\"dojoTooltip\">\n\t<div class=\"dijitTooltipContainer dijitTooltipContents\" dojoAttachPoint=\"containerNode\" dojoAttachEvent=\"onmouseenter:_mouseIn,onmouseleave:_mouseOut\" waiRole='alert'></div>\n\t<div class=\"dijitTooltipConnector\" dojoAttachPoint=\"connectorNode\"></div>\n</div>\n"),
		_mouseIn: function(e) {
			this.tooltipobj._hovering = true;
		},
		_mouseOut: function(e) {
			this.tooltipobj._hovering = false;
			this.hide(this._saveAroundNode);
			if(this.tooltipobj._showTimer) {
				clearTimeout(this.tooltipobj._showTimer);
				delete this.tooltip._showTimer;
			}
		},

		show: function(/*String*/ innerHTML, /*DomNode*/ aroundNode, /*String[]?*/ position, /*Boolean*/ rtl, tooltipobj){
			// summary:
			//		Display tooltip w/specified contents to right of specified node
			//		(To left if there's no space on the right, or if rtl == true)
			this.tooltipobj = tooltipobj;
			this.tooltipobj._hovering = false;

			this._saveAroundNode = aroundNode;

			if(this.aroundNode && this.aroundNode === aroundNode){
				return;
			}

			if(this.fadeOut.status() == "playing"){
				// previous tooltip is being hidden; wait until the hide completes then show new one
				this._onDeck=arguments;
				return;
			}
			this.containerNode.innerHTML=innerHTML;

			var pos = dijit.placeOnScreenAroundElement(this.domNode, aroundNode, dijit.getPopupAroundAlignment((position && position.length) ? position : dijit.Tooltip.defaultPosition, !rtl), dojo.hitch(this, "orient"));

			// show it
			dojo.style(this.domNode, "opacity", 0);
			this.fadeIn.play();
			this.isShowingNow = true;
			this.aroundNode = aroundNode;
		}
	}
);

dijit.showTooltip = function(/*String*/ innerHTML, /*DomNode*/ aroundNode, /*String[]?*/ position, /*Boolean*/ rtl, tooltipobj){
	// summary:
	//		Display tooltip w/specified contents in specified position.
	//		See description of dijit.Tooltip.defaultPosition for details on position parameter.
	//		If position is not specified then dijit.Tooltip.defaultPosition is used.
	if(!dijit._masterTT){ dijit._masterTT = new vcldojo._MasterTooltip(); }
	return dijit._masterTT.show(innerHTML, aroundNode, position, rtl, tooltipobj);
};

dijit.hideTooltip = function(aroundNode){
	// summary:
	//		Hide the tooltip
	if(!dijit._masterTT){ dijit._masterTT = new vcldojo._MasterTooltip(); }
	return dijit._masterTT.hide(aroundNode);
};

dojo.declare(
	"vcldojo.HoverTooltip",
	dijit.Tooltip,
	{
		_hovering: false,
		_onUnHover: function(e) {
			if(this._focus){ return; }

			if(this._showTimer){
				clearTimeout(this._showTimer);
				delete this._showTimer;
			}
			if(! this._hideTimer) {
				this._hideTimer = setTimeout(dojo.hitch(this, function(){this.close()}), 500);
			}
		},

		open: function(/*DomNode*/ target){
 			// summary:
			//		Display the tooltip; usually not called directly.
			// tags:
			//		private

			if(this._showTimer){
				clearTimeout(this._showTimer);
				delete this._showTimer;
			}
			dijit.showTooltip(this.label || this.domNode.innerHTML, target, this.position, !this.isLeftToRight(), this);

			this._connectNode = target;
			this.onShow(target, this.position);
		},

		close: function(){
			// summary:
			//		Hide the tooltip or cancel timer for show of tooltip
			// tags:
			//		private
			if(this._hovering == true) {
				return;
			}

			if(this._connectNode){
				// if tooltip is currently shown
				dijit.hideTooltip(this._connectNode);
				delete this._connectNode;
				this.onHide();
			}
			if(this._showTimer){
				// if tooltip is scheduled to be shown (after a brief delay)
				clearTimeout(this._showTimer);
				delete this._showTimer;
			}
		}
	}
);

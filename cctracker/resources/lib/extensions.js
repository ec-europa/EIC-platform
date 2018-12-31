(function ($axel) {

  // expandURL('foo/bar.xml', '/delete') -> 'foo/bar/delete'
  function expandURL( url, path ) {
    var m = url.match(/([^\.\?]*)(\.\w+)?(\?.*)?/);
    return m[1] + path + (m[3] ? m[3] : '');
  }

  var _Constant = {

    ////////////////////////
    // Life cycle methods //
    ////////////////////////

    onGenerate : function ( aContainer, aXTUse, aDocument ) {
      var media = this.getParam('constant_media'),
          htag = (media === 'image') ? 'img' : (((media === 'url') || (media === 'email') || (media === 'file')) ? 'a' : (aXTUse.getAttribute('handle') || 'span')),
          h = xtdom.createElement(aDocument, htag),
          id = this.getParam('id'),
          t;
      if (media !== 'image') { // assumes 'text'
        t = xtdom.createTextNode(aDocument, '');
        h.appendChild(t);
        if ((media === 'url') || (media === 'file')) {
          xtdom.setAttribute(h, 'target', '_blank');
          $(h).click(function(ev) { if ($(ev.target).hasClass('nolink')) { xtdom.preventDefault(ev)}; } );
        }
      }
      if (id) { // FIXME: id to be supported directly as an xt:use attribute (?)
        xtdom.setAttribute(h, 'id', id);
      }
      aContainer.appendChild(h);
      return h;
    },

    onInit : function ( aDefaultData, anOptionAttr, aRepeater ) {
      this._setData(aDefaultData);
      if (this.getParam('hasClass')) {
        xtdom.addClassName(this._handle, this.getParam('hasClass'));
      }
      if (this.getParam('_Output')) {
        this._Output = this.getParam('_Output');
      }
    },

    onAwake : function () {
      // nop
    },

    onLoad : function (aPoint, aDataSrc) {
      var _value, _default, _disp, _output;
      if (aPoint !== -1) {
        _value = aDataSrc.getDataFor(aPoint);
        _default = this.getDefaultData();
        this._setData(_value || _default, aPoint[0].getAttribute('_Display'));
        this.setModified(_value && (_value !==  _default));
        this.set(false);
        this._Output = aPoint[0].getAttribute('_Output');
      } else {
        delete this._Output;
        this.clear(false);
      }
    },

    onSave : function (aLogger) {
      var val, tag, i;
      if ((this.isOptional() && (!this.isSet())) || (this.getParam('noxml') === 'true')) {
        aLogger.discardNodeIfEmpty();
      } else if (this._data) {
        tag = this.getParam('xValue');
        if (tag)  { // special XML serialization from _Output
          if (this._Output) {
            val = this._Output.split(" ");
            for (i = 0; i < val.length; i++) {
              aLogger.openTag(tag);
              aLogger.write(val[i]);
              aLogger.closeTag(tag);
            }
          } else {
            xtiger.cross.log('error', "missing _Output in 'constant' plugin");
          }
        } else {
          val = this.getParam('value');
          aLogger.write(val || this._data);
        }
      }
    },

    ////////////////////////////////
    // Overwritten plugin methods //
    ////////////////////////////////

    api : {
    },

    /////////////////////////////
    // Specific plugin methods //
    /////////////////////////////

    methods : {

      // Sets current data model and updates DOM view accordingly
      _setData : function (aData, display) {
        var base, path, media = this.getParam('constant_media');
        if (media === 'image') {
          if (aData) {
            base = this.getParam('image_base');
            path = base ? base + aData : aData;
          } else {
            path = this.getParam('noimage');
          }
          xtdom.setAttribute(this._handle, 'src', path);
        } else {
          if (this._handle.firstChild) {
            this._handle.firstChild.data = display || aData || '';
          }
          if (media === 'url') {
            path = this._handle.firstChild.data.match(/^(http:\/\/)?(.*)$/);
            xtdom.setAttribute(this._handle, 'href', path[1] ? path[0] : 'http://' + path[2]);
          } else if (media === 'file') {
            if (aData) {
              base = this.getParam('file_base');
              path = base ? base + '/' + aData : aData;
              $(this._handle).removeClass('nolink');
            } else {
              path = '';
              $(this._handle).addClass('nolink');
            }
            xtdom.setAttribute(this._handle, 'href', path);
          } else if (media === 'email') {
            path = this._handle.firstChild.data;
            if (/^\s*$|^\w([-.]?\w)+@\w([-.]?\w)+\.[a-z]{2,6}$/.test(path)) {
              xtdom.setAttribute(this._handle, 'href', 'mailto:' + path);
            } else {
              xtdom.setAttribute(this._handle, 'href', '#'); // FIXME: remove href (?)
            }
          }
          if (this.getParam('constant_colorize') === 'balance') { // DEPRECATED
            this._handle.style.color = (parseInt(aData) >= 0 ) ? 'green' : 'red';
          }
        }

        this._data = aData;
      },

      update : function ( aData ) {
        this._setData(aData.toString());
      },

      dump : function () {
        return this._data;
      },

      // Returns current data model
      getData : function () {
        return this._data;
      },

      // Clears the model and sets its data to the default data.
      // Unsets it if it is optional and propagates the new state if asked to.
      clear : function (doPropagate) {
        this._setData(this.getDefaultData());
        this.setModified(false);
        if (this.isOptional() && this.isSet()) {
          this.unset(doPropagate);
        }
      }
    }
  };

  $axel.plugin.register(
    'constant',
    { filterable: true, optional: true },
    {
      visibility : 'visible'
    },
    _Constant
  );

  /*****************************************************************************\
  |                                                                             |
  |  'augment' command object                                                   |
  |                                                                             |
  |*****************************************************************************|
  |                                                                             |
  |  Required attributes :                                                      |
  |  - data-target : id of the editor which contains the modal window           |
  |      which contains the template to transform to edit/create                |
  |  - data-augment-field : CSS selector of the wrapped set of which the first  |
  |      editing field will be augmented                                        |
  |  - data-augment-root : optional CSS selector of the closest ancestor        |
  |      of the command host to be used to scope the data-augment-field search  |
  |  Note :                                                                     |
  |  - data-template MUST be present on the target modal window                 |
  |  Optional attributes :                                                      |
  |  - data-create-src : URL of the controller to contact to POST new data      |
  |  - data-update-src : URL of the data to update (accepting GET / POST)       |
  |                                                                             |
  \*****************************************************************************/
  function AugmentCommand ( identifier, node ) {
    this.key = identifier;
    this.spec = $(node);
    this.editor = $('#' + identifier);
    this.modal = $('#' + this.spec.attr('data-target') + '-modal');
    this.spec.bind('click', $.proxy(this, 'execute'));
    this.viewing = false;
    node.axelCommand = this;
  }
  AugmentCommand.prototype = {
    // returns AXEL wrapped set for the monitored field(s)
    _getTarget : function () {
      var targetsel = this.spec.attr('data-augment-field'),
          rootsel = this.spec.attr('data-augment-root'),
          scope;
      if (rootsel) {
        scope = this.spec.closest(rootsel).get(0);
        if (scope) {
          return $axel($(targetsel, scope)); // scoped search
        }
      }
      return $axel(targetsel); // full document scope
    },
    _dismiss : function (event) {
      this.editor.unbind('axel-cancel-edit', $.proxy(this, 'cancel'));
      this.editor.unbind('axel-save-done', $.proxy(this, 'saved'));
      this.modal.off('hidden', $.proxy(this, 'cancel'));
      // this.editor.unbind('axel-editor-ready', $.proxy(this, 'stolen'));
      this.modal.modal('hide');
      // $('#' + this.spec.attr('data-target-ui')).hide();
      this.spec.get(0).disabled = false;
      this.viewing = false;
    },
    execute : function (event) {
      var ed = $axel.command.getEditor(this.key),
          win = $('#' + this.spec.attr('data-target')),
          goal = this.spec.attr('data-augment-mode'),
          src = this.spec.attr('data-update-src') || "",
          target, val, tpl;
     if (src && (src.indexOf('$_') !== -1)) {
        target = this._getTarget();
        // val = (target.length() > 1) ? target.get(0).dump() : target.text(); // FIXME: first(), getData() better than dump (AXEL api)
        val = target.get(0).dump();
        if (val) {
          src = src.replace('$_', val);
        } else {
          alert(this.spec.attr('data-augment-noref') || "You must select a name to edit the corresponding record");
          return;
        }
      }
      // sets title depending on goal
      target = win.parent().prev('.modal-header').children('h3').first();
      target.text(target.attr('data-when-' + goal));
      // generates editor
      tpl = win.attr('data-template');
      if (tpl.indexOf("?goal=") !== -1) { // quick fix supposing nothing after
        tpl = tpl.substr(0, tpl.indexOf("?goal="));
      }
      ed.transform(tpl + '?goal=' + goal);
      this.modal.modal('show');
      $('#' + this.spec.attr('data-target') + '-errors').removeClass('af-validation-failed');
      if ($axel(this.editor).transformed() && !this.viewing) { // assumes synchronous transform()
        this.viewing = true;
        this.spec.get(0).disabled = true;
        if (src === "") { // to set where to send data otherwise (creation)
          src = this.spec.attr('data-create-src') || "";
          ed.attr('data-src', src);
          if (!src) {
            xtiger.cross.log('debug','"augment" command with missing "data-create-src"');
          }
        } else {
          $axel(win).load(src);
          ed.attr('data-src', src); // to load data to edit
        }
        this.editor.bind('axel-cancel-edit', $.proxy(this, 'cancel'));
        this.editor.bind('axel-save-done', $.proxy(this, 'saved'));
        this.modal.on('hidden', $.proxy(this, 'cancel'));
        // this.editor.bind('axel-editor-ready', $.proxy(this, 'stolen'));
      }
    },
    // User has clicked cancel or clicked on the closing cross
    cancel : function (event) {
      if (this.viewing) {
        this._dismiss();
        $axel.command.getEditor(this.key).reset(true);
      }
    },
    saved : function (event, editor, source, xhr) {
      var target = this._getTarget().get(0),
          handle = $(target.getHandle()),
          payload = xhr.responseXML,
          name, value;

      this._dismiss();
      // FIXME: check Status="success"
      name = payload.getElementsByTagName("Name")[0].firstChild.data;
      value = payload.getElementsByTagName("Value")[0].firstChild.data;
      if (target && target.getUniqueKey().indexOf('choice') === 0) {
        handle.append('<option value="' + value + '">' + name + '</option>').val(value); // adds option and simulates user input
      }
      target.update(value);
      // handle.removeClass('select2-offscreen');
      if (target && target.getUniqueKey().indexOf('choice') === 0) {
        handle.trigger('change', { synthetic: true }); // propagates change (e.g. 'select2' filter needs it
        $axel.command.getEditor(this.key).reset(true);
      }
    }
    // Some other document editor loaded (only useful if non modal popup windows)
    // stolen : function (event) {
    //   if (this.viewing) {
    //     this._dismiss();
    //   }
    // }
  };

  $axel.command.register('augment', AugmentCommand, { check : false });

  /*****************************************************************************\
  |                                                                             |
  |  AXEL 'autofill' filter                                                     |
  |                                                                             |
  |  Listens to a change of value in its editor caused by user interaction      |
  |  (and not by loading data), then submit the change to a web service         |
  |  and loads its response into a target inside the editor.                    |
  |                                                                             |
  |*****************************************************************************|
  |                                                                             |
  |  Optional attributes :                                                      |
  |  - autofill_container : CSS selector of the HTML element containing the     |
  |      editor containing the target field, when this parameter is defined     |
  |      the filter also react to 'axel-content-ready' (editor's load           |
  |      completion event), this is useful for implementing lightweight         |
  |      transclusion                                                           |
  |  - autofill_root / autofill_target : CSS selector(s) of the subtree to fill |
  |      with data, if not defined filling starts at the first ancestor         |
  |      of the host element handle that matches autofill_target selector       |
  |                                                                             |
  |  Prerequisites :                                                            |
  |  - the web service MUST return an XML fragment compatible with the target   |
  |  - jQuery                                                                   |
  \*****************************************************************************/

  var _AutoFill = {

    onAwake : function () {
      var c = this.getParam('autofill_container');
      this.__autofill__onAwake();
      if (c) {
        // cannot directly subscribed to $(this.getHandle()).closest(c) since the generated editor has not yet been plugged into the container
        // FIXME: extend AXEL with a onEditorReady life cycle method (?)
        $(document).bind('axel-content-ready', $.proxy(this, 'contentLoaded'));
      }
    },

    //////////////////////////////////////////////////////
    // Overriden specific plugin methods or new methods //
    //////////////////////////////////////////////////////
    methods : {
      update : function (aData) {
        if (! this._autofill_running) {
          this.__autofill__update(aData);
          this.autofill();
        } // FIXME: short-circuit to avoid reentrant calls because select2 triggers 'change' on load
          // to synchronize it's own implementation with 'choice' model which triggers a call to update as a side effect...
      },
      contentLoaded : function (event, sourceNode) {
        if (sourceNode === $(this.getHandle()).closest(this.getParam('autofill_container')).get(0)) {
          this.autofill();
        }
      },
      autofill : function (event) {
        var target = this.getParam('autofill_target'),
            value = this.dump(), // FIXME: use getData ?
            url = this.getParam('autofill_url');
        if (target) { // sanity check
          if (value && url) { // sanity check
            if (!(event) || (event.target !== $(this.getHandle()).closest(target).get(0))) {
              // guard test is to avoid reentrant call since load() will trigger a bubbling 'axel-content-ready' event
              // FIXME: alternative solution si to extend load API with stg like load(url, { triggerEvent: false }) or load(url, { eventBubbling: false })
              url = url.replace(/\$_/g, value);
              this._autofill_running = true;
              $axel($(this.getHandle()).closest(target)).load(url);
              // $axel($(target, this.getDocument())).load(url);
              this._autofill_running = false;
            }
          } if (!value) {
            this._autofill_running = true;
            $axel($(this.getHandle()).closest(target)).load('<Reset/>'); // FIXME: implement $axel().reset()
            this._autofill_running = false;
          }
        }
      }
    }
  };

  $axel.filter.register(
    'autofill',
    { chain : [ 'update', 'onAwake' ] },
    { },
    _AutoFill
  );
  $axel.filter.applyTo({'autofill' : ['choice','constant']});

  /*****************************************************************************\
  |                                                                             |
  |  'c-delete' command object                                                    |
  |                                                                             |
  \*****************************************************************************/
  (function () {
    function DeleteCommand ( identifier, node ) {
      this.spec = $(node);
      this.spec.bind('click', $.proxy(this, 'execute'));
    }
    DeleteCommand.prototype = {

      // FIXME: manage server side error messages (and use 200 status)
      successCb : function (response, status, xhr) {
        var loc = xhr.getResponseHeader('Location'),
            proceed, target;
        if (loc) { // one shot protocol
          window.location.href = loc;
        } else if (xhr.status === 202) { // middle of transactional protocol
          proceed = confirm($('success > message', xhr.responseXML).text());
          if (proceed) {
            $.ajax({
              url : this.controller,
              // type : 'delete',
              type : 'post',
              data :  { '_delete' : 1 },
              cache : false,
              timeout : 20000,
              success : $.proxy(this, "successCb"),
              error : $.proxy(this, "errorCb")
            });
          }
        } else if (xhr.status === 200) { // end of transactional protocol
          alert($('success > message', xhr.responseXML).text());
          target = this.spec.attr('data-target'); // triggers 'axel-delete-done' on the target editor
          if (target) {
            target = $axel.command.getEditor(target);
            if (target) {
              target.trigger('axel-delete-done', this, xhr);
            }
          }
        } else {
          this.spec.trigger('axel-network-error', { xhr : xhr, status : "unexpected" });
        }
        this.spec.triggerHandler('axel-transaction-complete', { command : this });
      },

      errorCb : function (xhr, status, e) {
        this.spec.trigger('axel-network-error', { xhr : xhr, status : status, e : e });
        this.spec.triggerHandler('axel-transaction-complete', { command : this });
      },

      execute : function () {
        var ask = this.spec.attr('data-confirm'),
            target = this.spec.attr('data-target'),
            request = {
                  cache : false,
                  timeout : 20000,
                  success : $.proxy(this, "successCb"),
                  error : $.proxy(this, "errorCb")
                },
            proceed = true,
            ed, ctrl;

        if (ask) { // one shot version : directly send 'delete' action
          proceed = confirm(ask);
          request.type = 'post'; // should be 'delete' but we had pbs with tomcat / realm
          request.data = { '_delete' : 1 };
        } else { // transactional version : first request confirmation message from server with 'post' then send 'delete'
          request.type = 'post';
        }
        if (target) { // attached to an editor
          ed = $axel.command.getEditor(target);
          if (ed) {
            ctrl = ed.attr('data-src');
            if (ctrl) {
              if (/\.[\w\?=]*$/.test(ctrl)) {   // replaces end of URL with '/delete' (eg: .blend or .xml?goal=update)
                ctrl = ctrl.replace(/\.[\w\?=]*$/, '/delete'); 
            } else {
                ctrl = expandURL(ctrl, '/delete');
              }
            }
          }
        }
        this.controller = ctrl || this.spec.attr('data-controller');
        if (proceed) {
          request.url = this.controller;
          this.spec.triggerHandler('axel-transaction', { command : this });
          $.ajax(request);
        }
      }
    };
    $axel.command.register('c-delete', DeleteCommand, { check : false });
  }());

  /*****************************************************************************\
  |                                                                             |
  |  'c-inhibit' command object                                                    |
  |                                                                             |
  \*****************************************************************************/
  (function () {
    // User has clicked on a 'save' command trigger
    function startSave (event) {
      var spec = event.data,
          menu = spec.closest('.c-menu-scope');
      menu.find('button, a').hide();
      menu.append($('#c-saving').children('span.c-saving').clone(false));
    }

    // A 'save' action is finished
    function finishSave (event) {
      var spec = event.data;
          menu = spec.closest('.c-menu-scope');
      menu.find('button, a').show();
      menu.children('span.c-saving').remove('.c-saving');
    }

    function InhibitCommand ( identifier, node ) {
      var spec = $(node),
          sig = spec.attr('data-command');
      if (sig.indexOf('save') !== -1) { // on 'save' command
        $('#' + spec.attr('data-target'))
          .bind('axel-save', spec, startSave)
          .bind('axel-save-done', spec, finishSave)
          .bind('axel-save-error', spec, finishSave)
          .bind('axel-save-cancel', spec, finishSave);
      } else { // on 'status' or 'c-delete' command
        spec
          .bind('axel-transaction', spec, startSave)
          .bind('axel-transaction-complete', spec, finishSave);
      }
    }
    $axel.command.register('c-inhibit', InhibitCommand, { check : false });
  }());

  /*****************************************************************************\
  |                                                                             |
  |  'attachment' plugin to view an attachment inside a form                    |
  |                                                                             |
  \*****************************************************************************/
  (function ($axel) {

    // you may use the closure to declare private objects and methods here

    var _Editor = {

      ////////////////////////
      // Life cycle methods //
      ////////////////////////
      onGenerate : function ( aContainer, aXTUse, aDocument ) {
        var viewNode = xtdom.createElement (aDocument, 'div');
        aContainer.appendChild(viewNode);
        return viewNode;
      },

      onInit : function ( aDefaultData, anOptionAttr, aRepeater ) {
        if (this.getParam('hasClass')) {
          xtdom.addClassName(this._handle, this.getParam('hasClass'));
        }
      },

      // Awakes the editor to DOM's events, registering the callbacks for them
      onAwake : function () {
      },

      onLoad : function (aPoint, aDataSrc) {
        var i, h;
        if (aDataSrc.isEmpty(aPoint)) {
          $(this.getHandle()).html('');
         } else {
           h = $(this.getHandle());
           h.html('');
           for (i = 1; i < aPoint.length; i++) {
             h.append(aPoint[i]);
           }
        }
      },

      onSave : function (aLogger) {
        aLogger.write('HTML BLOB');
      },

      ////////////////////////////////
      // Overwritten plugin methods //
      ////////////////////////////////
      api : {
      },

      /////////////////////////////
      // Specific plugin methods //
      /////////////////////////////
      methods : {
      }
    };

    $axel.plugin.register(
      'attachment',
      { filterable: false, optional: false },
      {
       key : 'value'
      },
      _Editor
    );

  }($axel));

  /*****************************************************************************\
  |                                                                             |
  |  'switch' binding for conditional viewing                                   |
  |                                                                             |
  |  This is a rewrite of original 'condition' binding                          |
  |                                                                             |
  \*****************************************************************************/
  (function ($axel) {

    var _Switch = {

      onInstall : function ( host ) {
        this.disableClass = this.getParam('disable-class');
        this.avoidstr = 'data-avoid-' + this.getVariable();
        this.editor = $axel(host);
        host.bind('axel-update', $.proxy(this.updateConditionals, this));
        // command installation is post-rendering, hence we can change editor's state
        this.updateConditionals();
        // FIXME: should be optional (condition_container=selector trick as 'autofill' ?)
        $(document).bind('axel-content-ready', $.proxy(this, 'updateConditionals'));

      },

      methods : {

        // onset.foreach( addClass data-on-class, removeClass data-off-class )
        // offset.foreach( removeClass data-on-class, addCLass data-off-class )

        updateConditionals : function  (ev, editor) {
          var onset, offset;
          var curval = this.editor.text();
          var fullset = $('body [' + this.avoidstr + ']', this.getDocument());
          onset = (curval !== '') ? fullset.not('[' + this.avoidstr + '*="' + curval + '"]') : fullset.not('[' + this.avoidstr + '=""]');
          offset = (curval !== '') ? fullset.filter('[' + this.avoidstr + '*="' + curval + '"]') : fullset.filter('[' + this.avoidstr + '=""]');
          // data-disable-class rule
          if (this.disableClass) {
            onset.removeClass(this.disableClass);
            offset.addClass(this.disableClass);
          }
          // data-(on | off)-class distributed rules
          onset.filter('[data-on-class]').each(function (i, e) { var n = $(e); n.addClass(n.attr('data-on-class')); } );
          offset.filter('[data-on-class]').each(function (i, e) { var n = $(e); n.removeClass(n.attr('data-on-class')); } );
          onset.filter('[data-off-class]').each(function (i, e) { var n = $(e); n.removeClass(n.attr('data-off-class')); } );
          offset.filter('[data-off-class]').each(function (i, e) { var n = $(e); n.addClass(n.attr('data-off-class')); } );
        }
      }
    };

    $axel.binding.register('switch',
      null, // no options
      { 'disable-class' : undefined }, // parameters
      _Switch);
  }($axel));

  /*****************************************************************************\
  |                                                                             |
  |  'open' command object                                                    |
  |                                                                             |
  \*****************************************************************************/
  (function () {
    function doOpen (event) {
      var spec = event.data,
          f = $('#' + spec.attr('data-form')),
          action = $axel.resolveUrl(spec.attr('data-src'));
      f.attr('action', action);
      f.submit();
    }
    function OpenCommand ( identifier, node ) {
      var spec = $(node);
      spec.bind('click', spec, doOpen);
    }
    $axel.command.register('open', OpenCommand, { check : false });
  }());

}($axel));



/*****************************************************************************\
|                                                                             |
|  AXEL 'mandatory' binding                                                   |
|                                                                             |
|*****************************************************************************|
|  Prerequisites: jQuery, AXEL, AXEL-FORMS                                    |
|                                                                             |
\*****************************************************************************/

// TODO: make data-regexp optional if data-pattern is defined for HTML5 validation only

(function ($axel) {

  var _Mandatory = {

    onInstall : function ( host ) {
      var root, jroot;
      var doc = this.getDocument();
      this.editor = $axel(host);
      this.spec = host;

      host.bind('axel-update', $.proxy(this.check, this));
      $axel.binding.setValidation(this.editor.get(0), $.proxy(this.validate, this));
    },

    methods : {

      // Updates inline bound tree side-effects based on current data
      check : function  (when) {
        var valid = this.editor.text() != '',
            scope,
            label,
            doc = this.getDocument(),
            anchor = this.spec.get(0),
            iklass = this.spec.attr('data-mandatory-invalid-class'),
            type = this.spec.attr('data-mandatory-type'),
            // select2/choice2 plugin graphic control 
            a = this.spec.find('a.[class*="select2-choice"]'),
            k = this.spec.find(type).first().attr('class');

        if (a.length > 0) {
          k = a.first().attr('class');
          if (valid && k.indexOf(iklass) !== -1) {
            a.first().attr('class', k.substring(0, k.indexOf(iklass) - 1));
          } else if (!valid && k.indexOf(iklass) == -1) {
            a.first().attr('class', k + ' ' + iklass);
          }
        } else if (k) {
          if (valid && k.indexOf(iklass) !== -1) {
            this.spec.find(type).first().attr('class', k.substring(0,k.indexOf(iklass) - 1));
          } else if (!valid && k.indexOf(iklass) == -1) {
            this.spec.find(type).first().attr('class', k + ' ' + iklass);
          }
        }
        return valid;
      },
      
      // Updates inline bound tree side-effects based on current data
      // Returns true to block caller command (e.g. save) if invalid
      // unless data-validation is 'off'
      validate : function () {
        var res = this.check();
        return (this.spec.attr('data-validation') === 'off') || res;
      }
    }
  };

  $axel.binding.register('mandatory',
    { error : true  }, // options
    {  }, // parameters
    _Mandatory
  );

}($axel));




/**
 * AXEL-FORMS "choice2v2" plugin
 *
 * HTML forms "select/option" element wrapper
 *
 * Synopsis :
 *  - <xt:use types="choice2v2" param="noselect=---" values="one two three"/>
 *
 * TODO :
 *  - insert in keyboard manager focus chain
 */

(function ($axel) {

  var _Editor = (function () {

    // Utility to convert a hash objet into an html double-quoted style attribute declaration string
    function _style( rec ) {
      var key, tmp = [];
      for (key in rec) {
        if (rec[key]) {
          tmp.push(key + ':' + rec[key]);
        }
      }
      key = tmp.join(';');
      return key  ? ' style="' + key + '"' : '';
    }

   function _createPopup ( that, menu ) {
     var k1, k2, tmp = '',
         buff = that.getParam('choice2_width1'),
         style1 = _style({ 'width' : buff }),
         config2 = { 'left' : buff, 'width' : that.getParam('choice2_width2')},
         style2;
     if (that.getParam('choice2_position') === 'left') {
       config2['margin-left'] = '-' + (parseInt(buff) + parseInt(config2.width) + 2) + 'px';
     }
     style2 = _style(config2);
     for (k1 in menu) {
       buff = '';
       all = ''
       for (k2 in menu[k1]) {
         if (k2 !== '_label') {
           buff += '<li class="choice2-label" data-code="' + k2 + '">' + menu[k1][k2] + '</li>';
           all += (all == '' ? k2 : ',' + k2)
         }
       }
       tmp += '<li class="choice2-option" data-codes="' + all + '"><div class="choice2-item"' + style1 + '>' + menu[k1]._label + '</div><ul class="choice2-popup2 choice2-drop-container"' + style2 + '>' + buff + '</ul></li>';
     }
     tmp = '<ul class="choice2-popup1 choice2-drop-container"' + style1 + '>' + tmp.replace(/&/g,'&amp;') + '</ul>';
     $(that.getHandle()).append(tmp);
   }

   // Utility to select level 1 option when all level 2 options selected
   function _fixItemSelection ( item ) {
     if (0 === item.find('li.choice2-label:not(.selected)').size()) {
       item.addClass('selected');
     } else {
       item.removeClass('selected');
     }
   }

    // compute if new state is significative (i.e. leads to some non empty XML output)
   //  meaningful iff there is no default selection (i.e. there is a placeholder)
   function _calcChange (defval, model) {
     var res = true;
     if (! defval) {
       if (typeof model === "string") { // single
         res = model !== defval;
       } else { // multiple
         if (!model || ((model.length === 1) && !model[0])) {
           res = false;
         }
       }
     } else { // FIXME: assumes no multiple default values
       res = model !== defval;
     }
     return res;
   }

   return {

     ////////////////////////
     // Life cycle methods //
     ////////////////////////

     // Plugin static view: span showing current selected option
     onGenerate : function ( aContainer, aXTUse, aDocument ) {
      var viewNode,
          style = { 'width' : this.getParam('choice2_width0') };
      viewNode= xtdom.createElement (aDocument, 'div');
      xtdom.addClassName(viewNode,'axel-choice2');
      $(viewNode).html('<div class="select2-container-multi"' + _style(style) + '><ul class="select2-choices"></ul></div>');
      aContainer.appendChild(viewNode);
      return viewNode;
     },

     onInit : function ( aDefaultData, anOptionAttr, aRepeater ) {
       var values = this.getParam('values');
       if (this.getParam('hasClass')) {
         xtdom.addClassName(this._handle, this.getParam('hasClass'));
       }
       // builds options if not cloned from a repeater
       if (! aRepeater) {
          _createPopup(this, this.getParam('values'));
       }
     },

     onAwake : function () {
       var  _this = this,
            defval = this.getDefaultData(),
            pl = this.getParam("placeholder");
       if ((this.getParam('appearance') !== 'full') && (pl || (! defval))) {
         pl = pl || "";
         // inserts placeholder option
         // $(this._handle).prepend('<span class="axel-choice-placeholder">' + (pl || "") + '</span>');
         // creates default selection
         // if (!defval) {
           // this._param.values.splice(0,0,pl);
           // if (this._param.i18n !== this._param.values) { // FIXME: check its correct
           //   this._param.i18n.splice(0,0,pl);
           // }
           // if (pl) {
           //   $(this._handle).addClass("axel-choice-placeholder");
           // }
         // }
       }
      this._setData(defval);
      $(this._handle).children('div.select2-container-multi').click($.proxy(this, '_handleClickOnChoices'));
      $(this._handle).find('li.choice2-label').click($.proxy(this, '_handleClickOnLabel'));
      $(this._handle).find('div.choice2-item').click($.proxy(this, '_handleClickOnItem'));
     },

     onLoad : function (aPoint, aDataSrc) {
       var value, defval, option, xval,tmp;
       if (aDataSrc.isEmpty(aPoint)) {
         this.clear(false);
       } else {
         xval = this.getParam('xvalue');
         defval = this.getDefaultData();
         if (xval) { // custom label
           value = [];
           option = aDataSrc.getVectorFor(xval, aPoint);
           while (option !== -1) {
             tmp = aDataSrc.getDataFor(option);
             if (tmp) {
               value.push(tmp);
             }
             option = aDataSrc.getVectorFor(xval, aPoint);
         }

           this._setData(value.length > 0 ? value : "");
         } else { // comma separated list
           tmp = aDataSrc.getDataFor(aPoint);
           if (typeof tmp !== 'string') {
             tmp = '';
           }
           value = (tmp || defval).split(",");
           this._setData(value);
         }
         this.set(false);
         this.setModified(_calcChange(defval,value));
       }
     },

     onSave : function (aLogger) {
       var tag, data, i;
       if ((!this.isOptional()) || this.isSet()) {
         if (this._data && (this._data !== this.getParam('placeholder'))) {
           tag = this.getParam('xvalue');
           if (tag) {
             if (typeof this._data === "string") {
               aLogger.openTag(tag);
               aLogger.write(this._data);
               aLogger.closeTag(tag);
             } else {
               for (i=0;i<this._data.length;i++) {
                 if (this._data[i] !== "") { // avoid empty default (i.e. placeholder)
                   aLogger.openTag(tag);
                   aLogger.write(this._data[i]);
                   aLogger.closeTag(tag);
                 }
               }
             }
           } else {
             aLogger.write(this._data.toString().replace(/^,/,''));
           }
         }
       } else {
         aLogger.discardNodeIfEmpty();
       }
     },

     ////////////////////////////////
     // Overwritten plugin methods //
     ////////////////////////////////

     api : {

       // FIXME: first part is copied from Plugin original method,
       // an alternative is to use derivation and to call parent's method
       _parseFromTemplate : function (aXTNode) {
         var tmp, defval;
         this._param = {};
         xtiger.util.decodeParameters(aXTNode.getAttribute('param'), this._param);
         defval = xtdom.extractDefaultContentXT(aXTNode); // value space (not i18n space)
         tmp = aXTNode.getAttribute('option');
         this._option = tmp ? tmp.toLowerCase() : null;
         // completes parameter set
         var values = aXTNode.getAttribute('values'),
             _values = JSON.parse(values);
         this._param.values = _values;
         this._content = defval || "";
       },

       isFocusable : function () {
         return true;
       },

       focus : function () {
         // nop : currently Tab focusing seems to be done by the browser
       }
     },

     /////////////////////////////
     // Specific plugin methods //
     /////////////////////////////

     methods : {

       // Click on the list of current choices
       _handleClickOnChoices : function ( e ) {
         var t = $(e.target),
             h = $(e.target).closest('.axel-choice2'),
             n, pos, height, val;
         // Click in Placeholders
         if (t.hasClass('select2-choices') || t.hasClass('select2-label')) { // open/close popup
           pos = t.hasClass('select2-label') ? t.closest('.select2-choices').offset() : t.offset();
           height = t.hasClass('select2-label') ? t.closest('.select2-choices').height() : t.height();
           n = h.children('ul.choice2-popup1');
           if (n.hasClass('show')) { // will be closed
             $('div.select2-container-multi ul', this._handle).css('minHeight', ''); // unlock height
           }
           n.toggleClass('show').offset( { top : pos.top + height + 1, left: pos.left });
         }
         else if (t.hasClass('select2-search-choice-close'))
         { // remove single choice
           t = $(e.target).closest('li[data-code]').first();
           val = t.attr('data-code');
           if (typeof(val) !== 'undefined') {
             n = h.find('ul.choice2-popup1 li.choice2-label[data-code="' + val +'"]').removeClass('selected');
             this.removeFromSelection(val, n);
             t.remove();
           }
           else // remove Bulk choice
           {
             t = $(e.target).closest('li[data-codes]').first();
             val = t.attr('data-codes');
             n = h.find('ul.choice2-popup1 li.choice2-option[data-codes="' + val +'"]').removeClass('bulk-selected');
             this.removeBulkFromSelection(val, n);
           }
           e.stopPropagation();
         }
       },

       // Click on a popup level 1 option
       _handleClickOnItem :function (e) {
         var n = $(e.target),
             options = n.parent().find('li.choice2-label'),
             multiple = "yes" === this.getParam('multiple'),
             _this = this;
         if (multiple || (1 === options.size())) {
           if (n.parent().hasClass('bulk-selected')) {
             this.removeBulkFromSelection(n.parent().attr('data-codes'))
           } else if (n.parent().hasClass('selected')) {
             options.each(
               function (i,e) {
                 var n = $(e);
                 _this.removeFromSelection(n.attr('data-code'), false);
                 n.removeClass('selected');
               }
             );
           } else {
             if (! multiple) { // unselect the other
                this.setSelection([]);
             }
             _this.bulkSelection( n.text(), n.parent().attr('data-codes'), options.length)
             // single options removed from results as upgraded from op above
             options.each(
               function (i,e) {
                 var n = $(e);
                 if (n.hasClass('selected')) {
                   _this.removeFromSelection(n.attr('data-code'), false);
                   n.removeClass('selected');
                 }
               });
           }
           n.parent().toggleClass('bulk-selected');
         }
       },

       // Click on a popup level 2 option
       _handleClickOnLabel : function (e) {
         var n = $(e.target), _this = this;
         if (("yes" !== this.getParam('multiple')) && !n.hasClass('selected')) { // unselect the other
           this.setSelection([]);
         }
         if (n.parent().parent().hasClass('bulk-selected')) { // involves n.hasClass('selected')
           this.removeBulkFromSelection(n.parent().parent().attr('data-codes'))
           var options = n.parent().parent().find('li.choice2-label')
           options.each(
             function (i,e) {
               var nn = $(e)
               if (nn.text() !== n.text()) {
                 _this.addToSelection(nn.attr('data-code'), nn.text());
                 _fixItemSelection(nn.closest('.choice2-option'));
                 nn.addClass('selected');
               }
             });
           n.parent().parent().removeClass('bulk-selected')
         } else {
           n.toggleClass('selected');
           if (n.hasClass('selected')) { // has been selected
             var par = n.parent().parent()
             var all = par.find('li.choice2-label').length == par.find('li.choice2-label.selected').length
             if (all) { 
               var options = par.find('li.choice2-label')
               this.bulkSelection( par.find('div').text(), par.attr('data-codes'), options.length)
               // single options removed from results as upgraded from op above
               options.each(
                 function (i,e) {
                   var n = $(e);
                   _this.removeFromSelection(n.attr('data-code'), false);
                   n.removeClass('selected');
                 });
               par.toggleClass('bulk-selected');
             }
             else
             {
               this.addToSelection(n.attr('data-code'), n.text());
               _fixItemSelection(n.closest('.choice2-option'));
             }
           } else { // has been unselected
             this.removeFromSelection(n.attr('data-code'), n);
           }
         }
       },

       setSelection : function (values) {
         var tmp = '',
             set = $('li.choice2-label', this._handle),
             superset = $('li.choice2-option', this._handle),
             refined = values.join(),
             i, label;
         // reset all
         set.filter('.selected').removeClass('selected');
      
         if (values.length > 1) {
	   for (i = 0; i < superset.length; i++) {
	     var vals = values.join();
             var target = $(superset[i]).attr('data-codes')
             if (vals.indexOf(target) !== -1) {
               $(superset[i]).addClass('bulk-selected');
               tmp += '<li class="select2-search-choice bulk" data-codes="' + target + '"><div class="select2-label">' + $(superset[i]).find('div').first().text() + ' (all '+ target.split(',').length +')</div><a class="select2-search-choice-close" tabindex="-1" onclick="return false;" href="#"></a></li>';
               refined = refined.replace(target, '')
             }
           }
         }

         refined = refined.split(',')

         for (i = 0; i < refined.length; i++) {
           if (refined[i].length > 0) {
             label = set.filter('[data-code="' + refined[i] + '"]').first().addClass('selected').text();
             tmp += '<li class="select2-search-choice" data-code="' + refined[i] + '"><div class="select2-label">' + label.replace(/&/g,'&amp;') + '</div><a class="select2-search-choice-close" tabindex="-1" onclick="return false;" href="#"></a></li>';
           }
         }

         $('div.select2-container-multi > ul', this._handle).html(tmp);
         $('li.choice2-option', this._handle).each ( function (i, e) { _fixItemSelection($(e)); } );
       },

       bulkSelection : function (ground, values, sz) {         label = ground.replace(/&/g,'&amp;') +' (all '+ sz + ')'
         unique = '<li class="select2-search-choice bulk" data-codes="' + values + '"><div class="select2-label">' + label + '</div><a class="select2-search-choice-close" tabindex="-1" onclick="return false;" href="#"></a></li>';
         $('div.select2-container-multi > ul', this._handle).append(unique);
         this.implementPostAction();
       },

       addToSelection : function (value, name ) {
         var sel = $('div.select2-container-multi > ul', this._handle);
         if ((sel.find('li.select2-search-choice[data-code="' + value + '"]')).size() === 0) {
           sel.append(
             '<li class="select2-search-choice" data-code="' + value + '"><div class="select2-label">' + name.replace(/&/g,'&amp;') + '</div><a class="select2-search-choice-close" tabindex="-1" onclick="return false;" href="#"></a></li>'
             );
           this.implementPostAction();
         }
       },

       removeBulkFromSelection : function (value, checkParent) {
         var n = $('div.select2-container-multi ul', this._handle);
         if ($(this._handle).children('ul.choice2-popup1').hasClass('show')) {
           n.css('minHeight', n.height() + 'px'); // locks height to avoid "jump"
         }
         $('div.select2-container-multi li[data-codes="' + value + '"]', this._handle).remove();
         this.implementPostAction();
         n.removeClass('bulk-selected');
       },

       removeFromSelection : function (value, checkParent) {
         var n = $('div.select2-container-multi ul', this._handle);
         if ($(this._handle).children('ul.choice2-popup1').hasClass('show')) {
           n.css('minHeight', n.height() + 'px'); // locks height to avoid "jump"
         }
         $('div.select2-container-multi li[data-code="' + value + '"]', this._handle).remove();
         this.implementPostAction();
         if (checkParent) {
           checkParent.closest('.choice2-option').removeClass('selected');
           checkParent.closest('.choice2-option').removeClass('bulk-selected');
         }
       },
       
       implementPostAction : function () {
         if ('true' === this.getParam('choice2_closeOnSelect')) {
           $('ul.choice2-popup1', this._handle).removeClass('show');
         }
         var all = $('li.select2-search-choice', this._handle).map( function(i, e) { return $(e).attr('data-code'); } ).get()
         $('li.select2-search-choice[data-codes]', this._handle).map( function(i, e) { var codes = $(e).attr('data-codes').split(','); for (i in codes) all.push(codes[i]) } )
         this.update(all);
       },

       // FIXME: modifier l'option si ce n'est pas la bonne actuellement ?
       _setData : function ( value, withoutSideEffect ) {
         var values;
         this._data =  value || "";
         if (! withoutSideEffect) {
           values = typeof this._data === "string" ? [ this._data ] : this._data; // converts to array
           this.setSelection(values);
         }
       },

       dump : function () {
         return this._data;
       },

      // Updates the data model consecutively to user input
      // single: aData should be "" or any string value
      // multiple: aData should be null or [""] or any array of strings
       update : function (aData) {
         var meaningful = _calcChange(this.getDefaultData(), aData);
         this.setModified(meaningful);
         this._setData(aData, true);
         this.set(meaningful);
       },

       clear : function (doPropagate) {
         this._setData(this.getDefaultData());
         if (this.isOptional()) {
           this.unset(doPropagate);
         }
       }
     }
   };
  }());

  $axel.plugin.register(
    'choice2v2',
    { filterable: true, optional: true },
    {
    },
    _Editor
  );

  $axel.filter.applyTo({'event' : ['choice2v2']});
}($axel));


/**
 * AXEL-FORMS "choice3v2" plugin
 *
 * HTML forms "select/option" element wrapper
 *
 * Synopsis :
 *  - <xt:use types="choice3v2" param="noselect=---" values="one two three"/>
 *
 * TODO :
 *  - insert in keyboard manager focus chain
 */

(function ($axel) {

  var _Editor = (function () {

    // Utility to convert a hash objet into an html double-quoted style attribute declaration string
    function _style( rec ) {
      var key, tmp = [];
      for (key in rec) {
        if (rec[key]) {
          tmp.push(key + ':' + rec[key]);
        }
      }
      key = tmp.join(';');
      return key  ? ' style="' + key + '"' : '';
    }

   function _createPopup ( that, menu ) {
     var k1, k2, tmp = '',
         buff = that.getParam('choice2_width1'),
         style1 = _style({ 'width' : buff }),
         config2 = { 'left' : buff, 'width' : that.getParam('choice2_width2')},
         style2;
     if (that.getParam('choice2_position') === 'left') {
       config2['margin-left'] = '-' + (parseInt(buff) + parseInt(config2.width) + 2) + 'px';
     }
     style2 = _style(config2);
     for (k1 in menu) {
       buff = '';
       all = ''
       
       for (k2 in menu[k1]) {
         buff2 = '';
         all2 = '';
       
         if (k2 !== '_label') {
           for (k3 in menu[k1][k2]) {
             if (k3 !== '_label') {
               buff2 += '<li class="choice2-label" data-level="3" data-code="' + k3 + '">' + menu[k1][k2][k3] + '</li>';
               all2 += (all2 == '' ? k3 : ',' + k3)
             }
           }
           buff += '<li class="choice2-option2" data-level="2" data-codes="' + all2 + '"><div class="choice2-item"' + style1 + '>' + menu[k1][k2]._label + '</div><ul class="choice2-popup3 choice2-drop-container"' + style2 + '>' + buff2 + '</ul></li>';
           all += (all == '' ? all2 : ',' + all2)
         }
         
       }
       
       tmp += '<li class="choice2-option" data-level="1" data-codes="' + all + '"><div class="choice2-item"' + style1 + '>' + menu[k1]._label + '</div><ul class="choice2-popup2 choice2-drop-container"' + style2 + '>' + buff + '</ul></li>';
     }
     tmp = '<ul class="choice2-popup1 choice2-drop-container"' + style1 + '>' + tmp.replace(/&/g,'&amp;') + '</ul>';
     $(that.getHandle()).append(tmp);
   }

   // compute if new state is significative (i.e. leads to some non empty XML output)
   //  meaningful iff there is no default selection (i.e. there is a placeholder)
   function _calcChange (defval, model) {
     var res = true;
     if (! defval) {
       if (typeof model === "string") { // single
         res = model !== defval;
       } else { // multiple
         if (!model || ((model.length === 1) && !model[0])) {
           res = false;
         }
       }
     } else { // FIXME: assumes no multiple default values
       res = model !== defval;
     }
     return res;
   }

   return {

     ////////////////////////
     // Life cycle methods //
     ////////////////////////

     // Plugin static view: span showing current selected option
     onGenerate : function ( aContainer, aXTUse, aDocument ) {
      var viewNode,
          style = { 'width' : this.getParam('choice2_width0') };
      viewNode= xtdom.createElement (aDocument, 'div');
      xtdom.addClassName(viewNode,'axel-choice2');
      $(viewNode).html('<div class="select2-container-multi"' + _style(style) + '><ul class="select2-choices"></ul></div>');
      aContainer.appendChild(viewNode);
      return viewNode;
     },

     onInit : function ( aDefaultData, anOptionAttr, aRepeater ) {
       var values = this.getParam('values');
       if (this.getParam('hasClass')) {
         xtdom.addClassName(this._handle, this.getParam('hasClass'));
       }
       // builds options if not cloned from a repeater
       if (! aRepeater) {
          _createPopup(this, this.getParam('values'));
       }
     },

     onAwake : function () {
       var  _this = this,
            defval = this.getDefaultData(),
            pl = this.getParam("placeholder");
       if ((this.getParam('appearance') !== 'full') && (pl || (! defval))) {
         pl = pl || "";
       }
      this._setData(defval);
      $(this._handle).children('div.select2-container-multi').click($.proxy(this, '_handleClickOnChoices'));
      $(this._handle).find('li.choice2-label').click($.proxy(this, '_handleClickOnItem'));
      $(this._handle).find('div.choice2-item').click($.proxy(this, '_handleClickOnItem'));
     },

     onLoad : function (aPoint, aDataSrc) {
       var value, defval, option, xval,tmp;

       $(this._handle).find('li').removeClass('selected').removeClass('bulk-selected')
       this.setSelection([])
       if (aDataSrc.isEmpty(aPoint)) {
         this.clear(false);
       } else {
         xval = this.getParam('xvalue');
         defval = this.getDefaultData();
         if (xval) { // custom label
           value = [];
           option = aDataSrc.getVectorFor(xval, aPoint);
           while (option !== -1) {
             tmp = aDataSrc.getDataFor(option);
             if (tmp) {
               value.push(tmp);
             }
             option = aDataSrc.getVectorFor(xval, aPoint);
           }

           for (i in value) {
             var item = $(this._handle).find('li.choice2-label[data-code="' + value[i] + '"]');
             var pitem = item.parent().parent()
             var ppitem = pitem.parent().parent()
             if (ppitem.hasClass('bulk-selected') || pitem.hasClass('bulk-selected')) continue;
           
             var pbselected = item.parent().parent().parent().find('li.choice2-label').map(function() { return $(this).attr('data-code');} ).get().join();
             var pnotin = $(pbselected.split(',')).not(value).get().length
             bselected = item.parent().find('li.choice2-label').map(function() { return $(this).attr('data-code');} ).get().join();
             var notin = $(bselected.split(',')).not(value).get().length

             if (pnotin == 0) { // all substrees completed -> select above level instead
               this.bulkSelection( ppitem.find('div').first().text(), ppitem.attr('data-codes'), ppitem.attr('data-codes').split(',').length)
               ppitem.addClass('bulk-selected')
             }
             else if (notin == 0) { // all substrees completed -> select above level instead
               this.bulkSelection( pitem.find('div').first().text(), pitem.attr('data-codes'), pitem.attr('data-codes').split(',').length)
               pitem.addClass('bulk-selected')
             }
             else if (!pitem.hasClass('bulk-selected'))
             {
               this.addToSelection(value[i], item.text()) //_setData(value[i])
               item.addClass('selected')
             }
           }
         } else { // comma separated list
           tmp = aDataSrc.getDataFor(aPoint);
           if (typeof tmp !== 'string') {
             tmp = '';
           }
           value = (tmp || defval).split(",");

           this._setData(value);
         }
         this.set(false);
         this.setModified(_calcChange(defval,value));
       }
     },


     onSave : function (aLogger) {
       var tag, data, i;
       if ((!this.isOptional()) || this.isSet()) {
         if (this._data && (this._data !== this.getParam('placeholder'))) {
           tag = this.getParam('xvalue');
           if (tag) {
             if (typeof this._data === "string") {
               aLogger.openTag(tag);
               aLogger.write(this._data);
               aLogger.closeTag(tag);
             } else {
               for (i=0;i<this._data.length;i++) {
                 if (this._data[i] !== "") { // avoid empty default (i.e. placeholder)
                   aLogger.openTag(tag);
                   aLogger.write(this._data[i]);
                   aLogger.closeTag(tag);
                 }
               }
             }
           } else {
             aLogger.write(this._data.toString().replace(/^,/,''));
           }
         }
       } else {
         aLogger.discardNodeIfEmpty();
       }
     },

     ////////////////////////////////
     // Overwritten plugin methods //
     ////////////////////////////////

     api : {

       // FIXME: first part is copied from Plugin original method,
       // an alternative is to use derivation and to call parent's method
       _parseFromTemplate : function (aXTNode) {
         var tmp, defval;
         this._param = {};
         xtiger.util.decodeParameters(aXTNode.getAttribute('param'), this._param);
         defval = xtdom.extractDefaultContentXT(aXTNode); // value space (not i18n space)
         tmp = aXTNode.getAttribute('option');
         this._option = tmp ? tmp.toLowerCase() : null;
         // completes parameter set
         var values = aXTNode.getAttribute('values'),
             _values = JSON.parse(values);
         this._param.values = _values;
         this._content = defval || "";
       },

       isFocusable : function () {
         return true;
       },

       focus : function () {
         // nop : currently Tab focusing seems to be done by the browser
       }
     },

     /////////////////////////////
     // Specific plugin methods //
     /////////////////////////////

     methods : {

       // Click on the list of current choices
       _handleClickOnChoices : function ( e ) {
         var t = $(e.target),
             h = $(e.target).closest('.axel-choice2'),
             n, pos, height, val;
             
         // Click in Placeholders
         if (t.hasClass('select2-choices') || t.hasClass('select2-label')) { // open/close popup
           pos = t.hasClass('select2-label') ? t.closest('.select2-choices').offset() : t.offset();
           height = t.hasClass('select2-label') ? t.closest('.select2-choices').height() : t.height();
           n = h.children('ul.choice2-popup1');
           
           console.log(n)
           if (n.hasClass('show')) { // will be closed
             $('div.select2-container-multi ul', this._handle).css('minHeight', ''); // unlock height
           }
           n.toggleClass('show').offset( { top : pos.top + height + 1, left: pos.left });
         }
         else if (t.hasClass('select2-search-choice-close'))
         { // remove single choice
           t = $(e.target).closest('li[data-code]').first();
           val = t.attr('data-code');
           if (typeof(val) !== 'undefined') {
             n = h.find('ul.choice2-popup1 li.choice2-label[data-code="' + val +'"]').removeClass('selected');
             this.removeFromSelection(val, n);
             t.remove();
           }
           else // remove Bulk choice
           {
             t = $(e.target).closest('li[data-codes]').first();
             val = t.attr('data-codes');
             n = h.find('ul.choice2-popup1 li[data-codes="' + val +'"]').removeClass('bulk-selected');
             this.removeBulkFromSelection(val, n);
           }
           e.stopPropagation();
         }
       },

       removeAllSubs : function ( item ) {
         var level = item.attr('data-level'), _this = this;
         
         if (level == '1') {
           var subitems = item.find('li.choice2-option2')
           subitems.each(
             function (i,e) {
               var rem = $(e);
               if (rem.hasClass('bulk-selected') || rem.hasClass('partial')) {
                 _this.removeBulkFromSelection(rem.attr('data-codes'), false);
                 rem.removeClass('bulk-selected')
                 rem.removeClass('partial')
               }
             }
           )
         }
         
         var leafs = item.find('li.choice2-label')
         leafs.each(
           function (i,e) {
             var rem = $(e);
             if (rem.hasClass('selected') || rem.hasClass('partial')) {
               _this.removeFromSelection(rem.attr('data-code'), false);
               rem.removeClass('selected')
             }
           }
         )
       },

       // Click on a node/leaf 
       _handleClickOnItem :function (e) {
         var n = $(e.target);
         var item = n.parent();
         var level = item.attr('data-level');
         var _this = this;
         
         // lazy init
         
         if (level == '1') {
           this.removeAllSubs( item ) // on completion or not, we flush all subtrees
           if (!item.hasClass('bulk-selected')) { // zero or several subtopics/leafs in it -> completion
             this.bulkSelection( n.text(), item.attr('data-codes'), item.attr('data-codes').split(',').length)
             item.addClass('bulk-selected')
           }
           else // all leafs bundled selected -> remove this item from placeholder
           {
             this.removeBulkFromSelection(item.attr('data-codes'), false);
             item.removeClass('bulk-selected')
           }
         }
         else if (level == '2')// level 2
         {
           var pitem = n.parent().parent().parent()
           if (pitem.hasClass('bulk-selected')) { // include into an entire selected subtrees so let's remove this item and its leafs and add all of its siblings
             this.removeBulkFromSelection(pitem.attr('data-codes'), false);
             pitem.removeClass('bulk-selected')
             
             var siblings = item.parent().find('li.choice2-option2:not([data-codes = "' + item.attr('data-codes') + '"])')
             siblings.each(
               function (i,e) {
                 var add = $(e);
                 _this.bulkSelection(add.find('div').text(), add.attr('data-codes'), add.attr('data-codes').split(',').length);
                 add.addClass('bulk-selected')
               }
             )
           }
           else // selected or not
           {
             this.removeAllSubs( item )
             if (!item.hasClass('bulk-selected')) { // not selected
               
               // test if all siblings are selected
               var l = item.parent().find('li.choice2-option2').length
               var bselected = item.parent().find('li.choice2-option2.bulk-selected').length
               
               if (bselected + 1 == l) { // all substrees completed -> select above level instead 
                 this.removeAllSubs( pitem )
                 this.bulkSelection( n.text(), pitem.attr('data-codes'), pitem.attr('data-codes').split(',').length)
                 pitem.addClass('bulk-selected')
               }
               else {
                 this.bulkSelection( n.text(), item.attr('data-codes'), item.attr('data-codes').split(',').length)
                 item.addClass('bulk-selected')
               }
             }
             else // selected
             {
               this.removeBulkFromSelection(item.attr('data-codes'), false);
               item.removeClass('bulk-selected')
             }
           }
         }
         else // leaf 
         {
           var pitem = n.parent().parent()
           var ppitem = pitem.parent().parent()
           var item = n;
           
           if (ppitem.hasClass('bulk-selected')) { // include into an entire selected subtrees so let's remove this item and its leafs and add all of its siblings
             this.removeBulkFromSelection(ppitem.attr('data-codes'), false);
             ppitem.removeClass('bulk-selected')
             
             var siblings = item.parent().find('li.choice2-label:not([data-code = "' + item.attr('data-code') + '"])');
             siblings.each(
               function (i,e) {
                 var add = $(e);
                 _this.addToSelection( add.attr('data-code'), add.text());
                 add.addClass('selected')
               }
             )
             
             var psiblings = pitem.parent().find('li.choice2-option2:not([data-codes = "' + pitem.attr('data-codes') + '"])')
             psiblings.each(
               function (i,e) {
                 var add = $(e);
                 _this.bulkSelection(add.find('div').text(), add.attr('data-codes'), add.attr('data-codes').split(',').length);
                 add.addClass('bulk-selected')
               }
             )
           }
           else if (pitem.hasClass('bulk-selected')) {
             this.removeBulkFromSelection(pitem.attr('data-codes'), false);
             pitem.removeClass('bulk-selected')
             
             var siblings = item.parent().find('li.choice2-label:not([data-code = "' + item.attr('data-code') + '"])')
             siblings.each(
               function (i,e) {
                 var add = $(e);
                 _this.addToSelection( add.attr('data-code'), add.text());
                 add.addClass('selected')
               }
             )
           }
           else // selected or not
           {
             if (!item.hasClass('selected')) {
               // test if all siblings are selected
               var l = item.parent().find('li.choice2-label').length
               var bselected = item.parent().find('li.choice2-label.selected').length
               if (bselected + 1 == l) { // all substrees completed -> select above level instead 
                 this.removeAllSubs( pitem )
                 this.bulkSelection( n.text(), pitem.attr('data-codes'), pitem.attr('data-codes').split(',').length)
                 pitem.addClass('bulk-selected')
               }
               else
               {
                 this.addToSelection( item.attr('data-code'), item.text())
                 item.addClass('selected')
                 this.removeAllSubs( item )
               }
             }
             else
             {
               this.removeFromSelection(item.attr('data-code'), false);
               item.removeClass('selected')
             }
           }
           
         }
       },

       setSelection : function ( values ) {
         var tmp = '',
             set = $('li.choice2-label', this._handle),
             i, label;
         // reset all
         set.filter('.selected').removeClass('selected');
         for (i = 0; i < values.length; i++) {
           if (values[i].length > 0) {
             label = set.filter('[data-code="' + values[i] + '"]').first().addClass('selected').text();
             tmp += '<li class="select2-search-choice" data-code="' + values[i] + '"><div class="select2-label">' + label.replace(/&/g,'&amp;') + '</div><a class="select2-search-choice-close" tabindex="-1" onclick="return false;" href="#"></a></li>';
           }
         }
         $('div.select2-container-multi > ul', this._handle).html(tmp);
       }, 

       bulkSelection : function (ground, values, sz) {
         label = ground.replace(/&/g,'&amp;') +' (all '+ sz + ')'
         unique = '<li class="select2-search-choice bulk" data-codes="' + values + '"><div class="select2-label">' + label + '</div><a class="select2-search-choice-close" tabindex="-1" onclick="return false;" href="#"></a></li>';
         $('div.select2-container-multi > ul', this._handle).append(unique);
         this.implementPostAction();
       },

       addToSelection : function (value, name ) {
         var sel = $('div.select2-container-multi > ul', this._handle);
         if ((sel.find('li.select2-search-choice[data-code="' + value + '"]')).size() === 0) {
           sel.append(
             '<li class="select2-search-choice" data-code="' + value + '"><div class="select2-label">' + name.replace(/&/g,'&amp;') + '</div><a class="select2-search-choice-close" tabindex="-1" onclick="return false;" href="#"></a></li>'
             );
           this.implementPostAction();
         }
       },

       removeBulkFromSelection : function (value, checkParent) {
         var n = $('div.select2-container-multi ul', this._handle);
         if ($(this._handle).children('ul.choice2-popup1').hasClass('show')) {
           n.css('minHeight', n.height() + 'px'); // locks height to avoid "jump"
         }
         $('div.select2-container-multi li[data-codes*="' + value + '"]', this._handle).remove();
         this.implementPostAction();
       },

       removeFromSelection : function (value, checkParent) {
         var n = $('div.select2-container-multi ul', this._handle);
         if ($(this._handle).children('ul.choice2-popup1').hasClass('show')) {
           n.css('minHeight', n.height() + 'px'); // locks height to avoid "jump"
         }
         $('div.select2-container-multi li[data-code="' + value + '"]', this._handle).remove();
         this.implementPostAction();
         if (checkParent) {
           checkParent.closest('.choice2-option').removeClass('selected');
           checkParent.closest('.choice2-option').removeClass('bulk-selected');
         }
       },
       
       implementPostAction : function () {
         if ('true' === this.getParam('choice2_closeOnSelect')) {
           $('ul.choice2-popup1', this._handle).removeClass('show');
         }
         var all = $('li.select2-search-choice', this._handle).map( function(i, e) { return $(e).attr('data-code'); } ).get()
         $('li.select2-search-choice[data-codes]', this._handle).map( function(i, e) { var codes = $(e).attr('data-codes').split(','); for (i in codes) all.push(codes[i]) } )
         this.update(all);
       },

       // FIXME: modifier l'option si ce n'est pas la bonne actuellement ?
       _setData : function ( value, withoutSideEffect ) {
         var values;
         this._data =  value || "";
         if (! withoutSideEffect) {
           values = typeof this._data === "string" ? [ this._data ] : this._data; // converts to array
           this.setSelection(values);
         }
       },

       dump : function () {
         return this._data;
       },

      // Updates the data model consecutively to user input
      // single: aData should be "" or any string value
      // multiple: aData should be null or [""] or any array of strings
       update : function (aData) {
         var meaningful = _calcChange(this.getDefaultData(), aData);
         this.setModified(meaningful);
         this._setData(aData, true);
         this.set(meaningful);
       },

       clear : function (doPropagate) {
         this._setData(this.getDefaultData());
         if (this.isOptional()) {
           this.unset(doPropagate);
         }
       }
     }
   };
  }());

  $axel.plugin.register(
    'choice3v2',
    { filterable: true, optional: true },
    {
    },
    _Editor
  );

  $axel.filter.applyTo({'event' : ['choice3v2']});
}($axel));


  /*****************************************************************************\
  |                                                                             |
  |  'switch' binding for conditional viewing                                   |
  |  Behaviour: intersection with targeted values is triggering updates         |
  |  accordingly                                                                |
  |  This is a rewrite of original 'condition' binding                          |
  |                                                                             |
  \*****************************************************************************/
  (function ($axel) {

    var _Switch = {

      onInstall : function ( host ) {
        this.disableClass = this.getParam('disable-class');
        this.avoidstr = 'data-avoid-' + this.getVariable();
        this.editor = $axel(host);
        host.bind('axel-update', $.proxy(this.updateConditionals, this));
        // command installation is post-rendering, hence we can change editor's state
        this.updateConditionals();
        // FIXME: should be optional (condition_container=selector trick as 'autofill' ?)
        $(document).bind('axel-content-ready', $.proxy(this, 'updateConditionals'));
      },

      methods : {
        // onset.foreach( addClass data-on-class, removeClass data-off-class )
        // offset.foreach( removeClass data-on-class, addCLass data-off-class )

        updateConditionals : function  (ev, editor) {
          var onset, offset;
          var curval = this.editor.text();
          var fullset = $('body [' + this.avoidstr + ']', this.getDocument());
          var vals = curval.split(' ')
          
          for (i=0; i < vals.length; ++i) {
            onset = (curval !== '') ? fullset.not('[' + this.avoidstr + '*="' + vals[i] + '"]') : fullset.not('[' + this.avoidstr + '=""]');
            // data-disable-class rule
            if (this.disableClass)
              onset.removeClass(this.disableClass);
            // data-(on | off)-class distributed rules
            onset.filter('[data-on-class]').each(function (i, e) { var n = $(e); n.addClass(n.attr('data-on-class')); } );
          }
          fullset = $('body [' + this.avoidstr + ']', this.getDocument()); 
          for (i=0; i < vals.length; ++i) {
            offset = (curval !== '') ? fullset.filter('[' + this.avoidstr + '*="' + vals[i] + '"]') : fullset.filter('[' + this.avoidstr + '=""]');
            
            // data-disable-class rule
            if (this.disableClass)
              offset.addClass(this.disableClass);
            offset.filter('[data-on-class]').each(function (i, e) { var n = $(e); n.removeClass(n.attr('data-on-class')); } );
          }
        }
      }
    };

    $axel.binding.register('switchv2',
      null, // no options
      { 'disable-class' : undefined }, // parameters
      _Switch);
  }($axel));
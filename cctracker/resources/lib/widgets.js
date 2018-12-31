/* Coach Match Widgets
 *
 * author      : Stéphane Sire
 * contact     : s.sire@oppidoc.fr
 * license     : LGPL v2.1
 * last change : 2016-09-30
 *
 * AXEL and AXEL-FORMS plugins and filters
 * AXEL-FORMS commands and bindings
 *
 * Prerequisites: jQuery + AXEL + AXEL-FORMS
 *
 * Plugins : constant
 *
 * Commands : ow-inhibit / ow-tab-control / ow-delete / ow-password
 *            ow-switch / ow-open / ow-load / ow-isave / autoscroll
 *            submit-once / ow-radar
 *
 * Bindings : confirm / cardinality
 *
 * 2016 - European Union Public Licence EUPL
 */
(function ($axel) {

  // expandURL('foo/bar.xml', '/delete') -> 'foo/bar/delete'
  function expandURL( url, path ) {
    var m = url.match(/([^\.\?]*)(\.\w+)?(\?.*)?/);
    return m[1] + path + (m[3] ? m[3] : '');
  }

  /*****************************************************************************\
  |                                                                             |
  |  'constant' plugin                                                          |
  |                                                                             |
  \*****************************************************************************/
  var _Constant = {

    ////////////////////////
    // Life cycle methods //
    ////////////////////////

    onGenerate : function ( aContainer, aXTUse, aDocument ) {
      var media = this.getParam('constant_media'),
          htag = (media === 'image') ? 'img' : (((media === 'url') || (media === 'email')) ? 'a' : (aXTUse.getAttribute('handle') || 'span')),
          h = xtdom.createElement(aDocument, htag),
          id = this.getParam('id'),
          t;
      if (media !== 'image') { // assumes 'text'
        t = xtdom.createTextNode(aDocument, '');
        h.appendChild(t);
        if (media === 'url') {
          xtdom.setAttribute(h, 'target', '_blank');
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
          } else if (media === 'email') {
            path = this._handle.firstChild.data;
            if (/^\s*$|^\w([-.]?\w)+@\w([-.]?\w)+\.[a-z]{2,}$/.test(path)) {
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
  |  'ow-inhibit' command object                                                |
  |                                                                             |
  |  Disables command trigger while loading and displays temporary message      |
  |  (which can be used to display a spining wheel)                             |
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
    $axel.command.register('ow-inhibit', InhibitCommand, { check : false });
  }());

  /*****************************************************************************\
  |                                                                             |
  |  'ow-tab-control' command object                                            |
  |                                                                             |
  |  Select / Hide tab based on user action or on 'save' command results        |
  |                                                                             |
  \*****************************************************************************/
  (function () {
    function TabControlCommand ( identifier, node ) {
      var spec = $(node),
          sig = spec.attr('data-command');

      // implements variable injection (on HTML input field)
      // FIXME: use 'constant' plugin instead ?
      if (spec.attr('data-insert-uuid') && spec.attr('data-insert-variable')) {
        $('[data-variable="'+ spec.attr('data-insert-variable') + '"]')
          .find('input')
          .val(spec.attr('data-insert-uuid'))
      }
      if (sig.indexOf('save') === -1) { // hosted on UI control
        spec.bind('click', $.proxy(this, 'execute'));
      } else { // hosted on 'save' command
        $('#' + spec.attr('data-target'))
          .bind('axel-save-done', $.proxy(this, 'successSave'))
      }
      this.spec = spec;
    }
      
    TabControlCommand.prototype = {

      successSave : function (event) {
        this.execute();
      },
      
      execute : function () {
        var target, editor, src;
        
        // implements data-disable-tab
        target = this.spec.attr('data-disable-tab');
        if (target) {
          $('a[href="#'+ target +'"]').addClass('ow-disable');
        }

        // implements data-hide-tab (assumes another tab is selected to hide content)
        target = this.spec.attr('data-hide-tab')
        if (target) {
          $('a[href="#'+ target +'"]').parent().css('display', 'none');
        }
        
        // implements data-select-tab (show, enable and select tab)
        target = this.spec.attr('data-select-tab');
        if (target) {
          $('a[href="#'+ target +'"]').removeClass('ow-disable').tab('show').parent().css('display', '');
        }
        
        // implements data-showdelete-tab (enable delete command in given tab)
        target = this.spec.attr('data-showdelete-tab');
        if (target) {
          $('#' + target).find('button[data-command*="ow-delete"]').show();
        }

        // reload data 
        target = this.spec.attr('data-reload-controller');
        if (target) {
          editor = $axel.command.getEditor(target);
          if (editor) {
            editor.reload();
          }
        }
      }
    };

    $axel.command.register('ow-tab-control', TabControlCommand, { check : false });
  }());

  /*****************************************************************************\
  |                                                                             |
  |  'ow-delete' command object                                                 |
  |                                                                             |
  |   POST to target editor's source + '/delete'                                |
  |                                                                             |
  \*****************************************************************************/

  // TODO : use $axel.oppidum to decode protocol

  (function () {
    function DeleteCommand ( identifier, node ) {
      this.spec = $(node);
      this.spec.bind('click', $.proxy(this, 'execute'));
    }
    DeleteCommand.prototype = {

      // FIXME: manage server side error messages (and use 200 status)
      successCb : function (response, status, xhr) {
        var loc = xhr.getResponseHeader('Location'),
            proceed, target, cmd;
        if (loc) { // one shot protocol
          window.location.href = loc;
        } else if (xhr.status === 202) { // middle of transactional protocol (no JSON ?)
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
          cmd = $axel.oppidum.getCommand(xhr);
          $axel.oppidum.handleMessage(cmd);
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
          if (ed) { // appends "/delete" to source path
            ctrl = ed.attr('data-src');
            if (ctrl) {
              ctrl = expandURL(ctrl, '/delete');
            }
          }
        }
        this.controller = this.spec.attr('data-controller') || ctrl; // data-controller override data-src if set  
        if (proceed) {
          request.url = this.controller;
          this.spec.triggerHandler('axel-transaction', { command : this });
          $.ajax(request);
        }
      }
    };
    $axel.command.register('ow-delete', DeleteCommand, { check : false });
  }());

  /*****************************************************************************\
  |                                                                             |
  |  'ow-password' command object                                                |
  |                                                                             |
  \*****************************************************************************/
  (function () {
    function PasswordCommand ( identifier, node ) {
      this.spec = $(node);
      this.spec.bind('click', $.proxy(this, 'execute'));
    }
    PasswordCommand.prototype = {

      // FIXME: manage server side error messages (and use 200 status)
      successCb : function (response, status, xhr) {
        alert($('success > message', xhr.responseXML).text());
        this.spec.triggerHandler('axel-transaction-complete', { command : this });
        var target = this.spec.attr('data-target');
        $('#' + target + '-modal').modal('hide'); // hides modal window (convention)
      },

      errorCb : function (xhr, status, e) {
        this.spec.trigger('axel-network-error', { xhr : xhr, status : status, e : e });
        this.spec.triggerHandler('axel-transaction-complete', { command : this });
      },

      execute : function () {
        var target = this.spec.attr('data-target'),
            ed, ctrl;
        if (target) { // attached to an editor
          ed = $axel.command.getEditor(target);
          if (ed) {
            ctrl = ed.attr('data-src'); // finishes path with "?regenerate=1"
            if (ctrl) {
              if (/[\.?].*$/.test(ctrl)) {
                // eats up any extension and parameters (eg: .blend or .xml?goal=update)
                ctrl = ctrl.replace(/[\.?].*$/, '?regenerate=1');
              } else {
                ctrl = ctrl + '?regenerate=1';
              }
            }
          }
        }
        if (ctrl) {
          this.spec.triggerHandler('axel-transaction', { command : this });
          $.ajax({
            url : ctrl,
            type : 'post',
            cache : false,
            timeout : 20000,
            success : $.proxy(this, "successCb"),
            error : $.proxy(this, "errorCb")
          });
        } else {
          alert('Missing AXEL command parameters !');
        }
      }
    };
    $axel.command.register('ow-password', PasswordCommand, { check : false });
  }());

  /*****************************************************************************\
  |                                                                             |
  |  'ow-switch' command                                                        |
  |                                                                             |
  |  Implements data-meet-{variable} to display menu groups                     |
  |  Works with 'ow-command'                                              |
  |                                                                             |
  |*****************************************************************************|
  |  Prerequisites: jQuery, AXEL, AXEL-FORMS                                    |
  |                                                                             |
  \*****************************************************************************/
  (function ($axel) {

    function SwitchCommand ( identifier, node ) {
      var src;
      this.spec = $(node);
      src = $('#' + this.spec.attr('data-event-source'));
      src.bind(this.spec.attr('data-event-type'), $.proxy(this, 'execute'));
      this.meetstr = 'data-meet-' + this.spec.attr('data-variable');
    }

    SwitchCommand.prototype = {
      execute : function (ev, curval) {
        var onset, offset, fullset;
        var fullset = $('*[' + this.meetstr + ']', this.spec.get(0));
        onset = fullset.filter('[' + this.meetstr + '*="' + curval + '"]');
        offset = fullset.not('[' + this.meetstr + '*="' + curval + '"]');

        onset.addClass('active');
        offset.removeClass('active');
      }
    };

    $axel.command.register('ow-switch', SwitchCommand, { check : false });
  }($axel));

  /*****************************************************************************\
  |                                                                             |
  |  'ow-open' command                                                          |
  |                                                                             |
  |  Loads XTiger deferred templates inside a tab upon activation               |
  |  Propagates optional data-event-type { name : data-event-name } event       |
  |  on data-event-target target upon successful template loading               |
  |                                                                             |
  |*****************************************************************************|
  |  Prerequisites: jQuery, AXEL, AXEL-FORMS                                    |
  |                                                                             |
  \*****************************************************************************/
  (function ($axel) {

    function OpenCommand ( identifier, node ) {
      this.spec = $(node);
      $('*[data-toggle="tab"][href="#' + this.spec.attr('id') + '"]').bind('show', $.proxy(this, 'execute'));
    }

    OpenCommand.prototype = {
      execute : function (ev) {
        var editor, ed, wset, evt,
            link = this.spec.attr('data-open-link'),
            edit = $('*[data-template][data-command="transform"]', this.spec.get(0));
        if (link) {
          window.location.href = link;
        }
        for (var i = 0; i < edit.length; i++) {
          editor = edit.eq(i).attr('id');
          ed = editor ? $axel.command.getEditor(editor) : undefined;
          if (ed) { // tab with template to load
            wset = $axel('#' + editor); // wset can be cached because lazy set
            if (wset.transformed()) {
              // Nop
            } else { // transforms deferred template
              ed.transform();
            }
            if (wset.transformed()) {
              // Pre-validate bindings (like cardinality)
              // TODO: integrate into editor.transform ?
              $axel.binding.validate(wset,
                undefined, // no concatenated display
                document);
            }
          }
        }
        evt = this.spec.attr('data-event-type');
        if (evt) {
          $('#' + this.spec.attr('data-event-target')).triggerHandler(evt, this.spec.attr('data-event-name'));
        }
      }
    };

    $axel.command.register('ow-open', OpenCommand, { check : false });
  }($axel));

  /*****************************************************************************\
  |                                                                             |
  |  'ow-load' command                                                          |
  |                                                                             |
  |  Reload XLM content of target editor                                        |
  |                                                                             |
  |*****************************************************************************|
  |  Prerequisites: jQuery, AXEL, AXEL-FORMS                                    |
  |                                                                             |
  |  Pre-conditions: target editor must have a data-src attribuet               |
  \*****************************************************************************/
  (function ($axel) {

    function LoadCommand ( identifier, node ) {
      this.spec = $(node);
      this.key = identifier;
      this.spec.bind('click', $.proxy(this, 'execute'));
    }

    LoadCommand.prototype = {
      // TODO: use asynchronous XHR (update AXEL/AXEL-FORMS)
      execute : function (ev) {
        var editor = $axel.command.getEditor(this.key),
            ed = document.getElementById(this.key);
        if (editor) {
          this.spec.attr('disabled', 'disable');
          editor.reload();
          this.spec.removeAttr('disabled');
          // FIXME: factorize in axel-forms ?
          // TODO: integrate into editor.reload ?
          $('*[class*="af-invalid"]', ed).removeClass('af-invalid');
          $('*[class*="af-required"]', ed).removeClass('af-required');
          $('*[class*="af-validation-failed"]',
            $(ed).closest('.tab-pane').get(0)).removeClass('af-validation-failed');
          $('*[class*="af-error"]', ed).hide();
          // Pre-validate bindings (like cardinality)
          // TODO: integrate into editor.reload ?
          $axel.binding.validate($axel(editor.spec), 
            undefined, // no concatenated display
            document);
        }
      }
    };

    $axel.command.register('ow-load', LoadCommand, { check : false });
  }($axel));

  /*****************************************************************************\
  |                                                                             |
  |  'ow-isave' command                                                         |
  |                                                                             |
  |  Instant save command                                                       |
  |                                                                             |
  |*****************************************************************************|
  |  Prerequisites: jQuery, AXEL, AXEL-FORMS                                    |
  \*****************************************************************************/
  (function ($axel) {

    function ISaveCommand ( identifier, node ) {
      this.spec = $(node);
      this.buffer = $axel(this.spec.get(0)).xml();
      this.spec.bind('axel-update', $.proxy(this, 'execute'));
    }

    ISaveCommand.prototype = {

      successCb : function (response, status, xhr) {
        var cmd = $axel.oppidum.getCommand(xhr),
            target;
        $axel.oppidum.handleMessage(cmd);
        target = this.spec.attr('data-replace-target');
        if (target) {
          $('#' + target).html($axel.oppidum.unmarshalPayload(xhr));
        }
      },

      errorCb : function (xhr, status, e) {
        this.spec.trigger('axel-network-error', { xhr : xhr, status : status, e : e });
      },

      // TODO: asynchronous and disable all editor fields (?)
      execute : function (ev) {
        var action = this.spec.attr('data-action'), tmp;
        if (action) {
          tmp = $axel(this.spec.get(0)).xml();
          if (this.buffer !== tmp ) {
            $.ajax({
              url : action,
              type : 'post',
              data : tmp,
              contentType : "application/xml; charset=UTF-8",
              dataType : 'xml',
              cache : false,
              timeout : 20000,
              async : false,
              success : $.proxy(this, "successCb"),
              error : $.proxy(this, "errorCb")
            });
            this.buffer = tmp;
          }
        }
      }
    };

    $axel.command.register('ow-isave', ISaveCommand, { check : false });
  }($axel));

}($axel));


(function ($axel) {

  var _Confirm = {

    onInstall : function ( host ) {
      this.editor = $axel(host);
      this.spec = host;
      host.bind('axel-update', $.proxy(this.confirm, this));
    },

    methods : {

      confirm : function () {
        var doc = this.getDocument(),
            host = this.spec,
            anchor = host.get(0),
            modal_body;

        if (this.editor.text() >= host.attr('data-confirm-value')) {
          // FIXME: could be replaced by hard-coded modal widget (limit server access)
          ed = $axel.command.getEditor(host.attr('data-confirm-modal-id'));
          ed.transform($axel.resolveUrl(host.attr('data-with-template'), this.spec.get(0)));
          dial = this.spec.attr('data-confirm-modal');
          $('#' + dial).modal('show');

          modal_body = $('#' + host.attr('data-confirm-modal-id'));
          // shared modal window grabbing (only one binding uses it at once)
          modal_body.unbind('axel-confirm-cancel');
          modal_body.unbind('axel-confirm-continue');
          modal_body.bind('axel-confirm-cancel', $.proxy(this.dismiss, this));
          modal_body.bind('axel-confirm-continue', $.proxy(this.nothing, this));

          this.spec.get(0).disabled = true;
        }
        return ;
      },

      dismiss : function (event) {
        var dial = this.spec.attr('data-confirm-modal');
        $('#' + dial).modal('hide');
        this.editor.load('<data/>'); // trick to cancel edit
      },

      nothing : function (event) { 
        var dial = this.spec.attr('data-confirm-modal');
        $('#' + dial).modal('hide');
      }
    }
  };

  $axel.binding.register('confirm',
    { error : true  }, // options
    { 'confirm-value' : $axel.binding.REQUIRED }, // parameters
    _Confirm
  );

}($axel));

(function ($axel) {

  var _Cardinality = {

    onInstall : function ( host ) {
      var pattern = host.attr('data-pattern'),
          target = host.attr('data-target'),
          counter = 0;

      host.find('tr').each(
        function(index) {
          if ($axel(this).text() == host.attr('data-cardinality-value'))
            counter ++;
        });

      this.editor = $axel(host);
      this.spec = host;
      host.bind('axel-update', $.proxy(this.check, this));

      // hook up onto first controlled field for insertion into validation
      $axel.binding.setValidation(this.editor.get(0), $.proxy(this.check, this));
    },

    methods : {
      check: function  () {
        var cnt = 0,
            max =  parseInt(this.spec.attr('data-cardinality-max')),
            ans = this.editor.text().split(' '),
            doc = this.getDocument(),
            anchor, scope, error;

        if (max - cnt >= 1) {
          $('[data-cardinality-radio*='+ this.spec.attr('data-variable') +']').each( 
            function(i) { $('input',$(this)).removeAttr('disabled'); }
          );
        }

        for (i = 0; i < ans.length; ++i) {
          cnt += (ans[i] == this.spec.attr('data-cardinality-value')) ? 1 : 0;
        }

        anchor = this.editor.get(0).getHandle(true);
        scope = $(anchor, doc).closest(this.errScope);
        error = $(this.errSel, scope.get(0));

        if (cnt > 0) {
          error.text((parseInt(this.spec.attr('data-cardinality-max')) - cnt) + ' left to mark');
        } else {
          error.text(parseInt(this.spec.attr('data-cardinality-max')) + ' max. to mark');
        }

        if (max - cnt === 0) {
          $('[data-cardinality-radio*='+ this.spec.attr('data-variable') +']').each( 
            function(i) { $('input',$(this)).attr('disabled',true); }
          );
        }
        
        return cnt <= max;
      },
    }
  };

  $axel.binding.register('cardinality',
    { error : true  }, // options
    { }, // parameters
    _Cardinality
  );

}($axel));

/*****************************************************************************\
|                                                                             |
|  'autoscroll' command object (Scroll towards an HTML element)               |
|                                                                             |
|*****************************************************************************|
|                                                                             |
|  Required attributes :                                                      |
|  - data-validation-output : identifier of the target element		      |
|                                                                             |
|                                                                             |
\*****************************************************************************/
(function () {
  
  function AutoScroll ( identifier, node ) {
    this.spec = $(node);

    var feedback = $('#' + this.spec.attr('data-validation-output'));
    if (feedback)
      feedback.on('axel-validate-error' , function(event) {
        $('html, body').animate( { scrollTop : feedback.offset().top }, 1000 );
    });
  }

  $axel.command.register('autoscroll', AutoScroll, { check : false });
}());

/*****************************************************************************\
|                                                                             |
|  'submit-once' command object                                               |
|                                                                             |
|*****************************************************************************|
|                                                                             |
|  Required attributes :                                                      |
|  - data-verb : root element name to construct fake payload for POST         |
|                                                                             |
\*****************************************************************************/
(function () {

  function Submit1Command ( identifier, node ) {
    this.spec = $(node);
    this.key = identifier; /* data-target */
    this.spec.bind('click', $.proxy(this, 'execute'));
    this.spec.prop('disabled', false);
  }

  Submit1Command.prototype = {

    successCb : function (response, status, xhr) {
      var cmd = $axel.oppidum.getCommand(xhr),
          target;
      $axel.oppidum.handleMessage(cmd);
      target = this.spec.attr('data-replace-target');
      if (target) {
        $('#' + target).html($axel.oppidum.unmarshalPayload(xhr));
      }
      this.spec.prop('disabled', true);
    },

    errorCb : function (xhr, status, e) {
      this.spec.trigger('axel-network-error', { xhr : xhr, status : status, e : e });
      this.spec.prop('disabled', false);
    },

    // Interprets data-src as a data island source already prefixed with #
    execute : function () {
      var src = this.spec.attr('data-verb'),
          ctrl = this.spec.attr('data-controller');
      this.spec.attr('disabled', true);
      $.ajax({
        url : ctrl,
        type : 'post',
        data : '<' + src + '/>',
        contentType : "application/xml",
        cache : false,
        timeout : 20000,
        async : false,
        success : $.proxy(this, "successCb"),
        error : $.proxy(this, "errorCb")
      });
    }
  };

  $axel.command.register('submit-once', Submit1Command, { check : false });
}());

/*****************************************************************************\
|                                                                             |
|  'ow-radar' command                                                         |
|                                                                             |
|  Queries JSON data on data source and plot radar view with legend           |
|                                                                             |
|*****************************************************************************|
|  Prerequisites: jQuery, AXEL, AXEL-FORMS, d3js, radar.js                    |
|                                                                             |
\*****************************************************************************/
(function ($axel) {

  function RadarCommand ( identifier, node ) {
    this.spec = $(node);
    $('*[data-toggle="tab"][href="#' + this.spec.attr('data-event-target') + '"]')
      .bind(this.spec.attr('data-event-type') + '.radar', $.proxy(this, 'execute'));
  }

  // TODO: factorize inside radar.js to share with cm-search.js
  // host can be given as CSS selector string or as DOM node
  function genRadar( host, data, config ) {
    var plot = [[]];
    // conversion to {axis, value} format
    data.forEach(function(p, i) {
      var v = parseFloat(p.Score),
          d = { axis : p.For,
                value : isNaN(v) ? 0 : Math.round(v * 10) / 1000
              };
      if (isNaN(v)) {
        d.miss = true;
      }
      plot[0].push(d);
    });
    $axel.RadarChart.draw(host, plot, config);
  }

  RadarCommand.prototype = {
    successCb : function (response, status, xhr) {
      $('#' + this.spec.attr('data-legend-target'))
        .text(response.Legend)
        .removeClass('cm-busy');
      if (response.Message) {
        $('#' + this.spec.attr('data-message-target')).text(response.Message).show();
      } else {
        $('#' + this.spec.attr('data-message-target')).hide();
      }
      if (response.Summary) {
        genRadar(this.spec.get(0), response.Summary.Axis,
          {
          w: 300,
          h: 300,
          maxValue: 1,
          levels: 5,
          ExtraWidthX: 200,
          TranslateX: 100,
          });
      } else {
        this.spec.children('svg').remove();
      }
      $('*[data-toggle="tab"][href="#' + this.spec.attr('data-event-target') + '"]')
        .unbind(this.spec.attr('data-event-type') + '.radar');
    },

    errorCb : function (xhr, status, e) {
      $('#' + this.spec.attr('data-legend-target'))
        .text('Could not load data : ' + $axel.oppidum.parseError(xhr, status, e))
        .removeClass('cm-busy');
    },

    execute : function (ev) {
      $('#' + this.spec.attr('data-legend-target')).text('...loading...').addClass('cm-busy');
      $.ajax({
        url : this.spec.attr('data-src'),
        type : 'post',
        async : false,
        data : '<Feeds/>',
        dataType : 'json',
        cache : false,
        timeout : 50000,
        contentType : "application/xml; charset=UTF-8",
        success : $.proxy(this, "successCb"),
        error : $.proxy(this, "errorCb")
      });
    }
  };

  $axel.command.register('ow-radar', RadarCommand, { check : false });
}($axel));


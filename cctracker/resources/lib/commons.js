/* Case Tracker Widgets Commons
 *
 * author      : Stéphane Sire
 * contact     : s.sire@oppidoc.fr
 * license     : LGPL v2.1
 * last change : 2016-09-30
 *
 * AXEL and AXEL-FORMS plugins and filters for Oppidum applications
 * AXEL-FORMS commands and bindings for Oppidum applications
 *
 * Prerequisites: jQuery + AXEL + AXEL-FORMS + d3.js (table factory)
 *
 * List of widgets
 * - table factory : $axel.command.makeTableCommand
 *
 * 2016 - European Union Public Licence EUPL
 *
 * DEPRECATED : moved to Exfront
 */

var typingTimer;

/*****************************************************************************\
|                                                                             |
|             Table factory $axel.command.makeTableCommand                    |
|                                                                             |
| - generates and registers '{name}-table' commands from a model hash         |
|   and a row encoding function (dependency injection)                        |
| - implements the Ajax JSON table protocol                                   |
|                                                                             |
| Hosting :                                                                   |
| - data-command='{name}-table' data-table-configure='sort filter'            |
|   on pre-generated table element                                            |
| - pre-generate table headers with data-sort="key" and data-filter="key"     |
|   for sortable / filterable columns                                         |
| - 2018/09/24 support for data-table-configure='analytics'                   |
|                                                                             |
\*****************************************************************************/
(function () {

  function _makeTableCommand ( name, encodeRowFunc, tableRowModel ) {
    var kommand = new Function(
                        ['key', 'node'],
                        'this.spec = $(node); this.table = this.spec.attr("id"); this.spec.bind("click",$.proxy(this,"handleAction")); this.modals={};this.config={};this.configure(this.spec.attr("data-table-configure"), this.spec.attr("data-editor"));'
                      );
    kommand.prototype = (function (encodeRowFunc, tableRowModel) {

      var _myEncodeRowFunc = function (d) { return encodeRowFunc(d, _encodeCell); },
          _myRowModel = tableRowModel,
          _mySorts = {},
          _name = name;

      // Generic column sort callback
      function _sortByHeaderCallback (ev) {
        var t = $(ev.target).closest('th'),
            table = t.closest('table'),
            tabctrl = $axel.command.getCommand(table.attr('data-command'), table.attr('id')),
            sortKey = t.attr('data-sort');

        if ((ev.target.nodeName.toUpperCase() !== 'INPUT') && tabctrl.sort) { // avoid filter input
          if (sortKey.charAt(0) === '-') { // inverse sort
            tabctrl.sort(sortKey.substr(1), true);
          } else {
            tabctrl.sort(sortKey);
          }
        }
      }

      // Default filter function
      function _filter(d, key, value) {
        return d[key] && (d[key].toUpperCase().indexOf(value) !== -1);
      }

      // Returns data encoding of a single cell for rendering
      function _encodeCell(key, data) {
        var val;
        if (data === undefined) {
          val = undefined;
        } else if (typeof data === 'string') {
          val = data;
        } else {
          val = data[key];
        }
        return { 'key' : key, 'value' : val};
      }

      // Renders a single encoded cell using a given model
      function _renderCell(d, i) {
        var model;
        if (d && typeof d === "object") {
          if (d.key) {
            model = _myRowModel[d.key];
            if (d.value) {
              if (model.yes === '*') {
                return '<a target="_blank">' + d.value + '</a>';
              } else if (model.yes === '@') {
                return '<a href="mailto:' + d.value + '">' + d.value + '</a>';
              } if (model.yes === '.') {
                return d.value;
              } else {
                return model.yes;
              }
            } else if (model.button) {
              return model.button;
            } else {
              return model.no;
            }
          } else {
            xtiger.cross.log('error', 'missing "key" property to render cell in '+ _name + ' table');
          }
        } else { // most probably "string" or "number"
          return d;
        }
      }

      return {

        // run once (triggered by data-table-configure)
        configure : function ( params, editor ) {
          if (params) {
            if (params.indexOf('analytics') !== -1) {
              if (!this.config.analytics) {
                this.config.analytics = this.spec.attr("data-analytics-controller") || 'analytics';
                var xml = $($.parseXML($axel('#' + editor).xml())).find('UUID') // TODO: peek
                this.config.uuid = xml.text();
              }
            }
            if (params.indexOf('sort') !== -1) {
              if (!this.config.sort) {
                this.spec.find("th[data-sort]").bind("click", _sortByHeaderCallback);
                this.config.sort = true;
              }
            }
            if (params.indexOf('filter') !== -1) {
              if (!this.config.filter) {
                this.spec.find("th[data-filter] input").bind('keyup', $.proxy(this, 'filter'));
                if (this.config.analytics) {
                  var _this = this;
                  this.spec.find("th[data-filter] input").bind('keyup',
                    function() {
                      var input = $(this),
                      key = input.closest('th').attr('data-filter'),
                      val = input.val(),
                      test;
                      if (key && val && val !== '') {
                        test = val.toUpperCase();
                        clearTimeout(typingTimer);
                        typingTimer = setTimeout(function() { _this.afterTyping(key, test) }, '5000');
                      }
                    });
                }
                this.config.filter = true;
              }
            }
          }
        },
        
        listen : function(action, target) {
          $.ajax({
            url : this.config.analytics + '/'+ this.config.uuid,
            // type : 'delete',
            type : 'post',
            data :  { 'action' : action, 'target' : target },
            cache : false,
            timeout : 20000
          });
        },

        // Change sort order if column already sorted, otherwise start with descending order
        // WARNING: d3.ascending(x, y) === 1 means
        // * x is superior to y (x, y numbers), thus they will be inverted when sorted
        // * x is after y in alphabetical order (x, y string), thus they will be inverted when sorted
        // thus for column display we use the term descending as sorted in alphabetical order
        // (hence the - prefix to inverse values encoded as numbers)
        sort : function (name, inverse) {
          var model = _myRowModel[name],
              d3rows = d3.select('#' + this.table + ' tbody').selectAll('tr'),
              jtable, jheader, sortFunc, ascend;
          if (d3rows.size() > 1) {
            jtable = $('#' + this.table);
            jheader = jtable.find('th[data-sort$=' + name +']');
            if ((_mySorts[name] === undefined) || ((!jheader.hasClass('ascending') && !(jheader).hasClass('descending')))) {
              ascend = true;
            } else {
              ascend = _mySorts[name] === true ? false : true;
            }
            if (model) {
              _mySorts[name] = ascend;
              if (inverse) {
                ascend = !ascend;
              }
              if (ascend) {
                sortFunc = _myRowModel[name].ascending || function (a, b) { return d3.ascending(a[name], b[name]); };
              } else {
                sortFunc = _myRowModel[name].descending || function (a, b) { return d3.descending(a[name], b[name]); };
              }
              if (sortFunc) { // TODO: spinning wheel ?
                d3rows.sort(sortFunc);
                jtable.find('th').removeClass('ascending').removeClass('descending');
                if ((inverse && !ascend) || (!inverse && ascend)) {
                  jheader.addClass('descending');
                  if (this.config.analytics) { this.listen('sort-desc', name) }
                } else {
                  jheader.addClass('ascending');
                  if (this.config.analytics) { this.listen('sort-asc', name) }
                }
              } else {
                xtiger.cross.log('error','table sort missing ordering functions for key ' + name);
              }
            } else {
              xtiger.cross.log('error','table sort unkown column model for key ' + name);
            }
          }
        },
        
        afterTyping : function (key, test) {
          var match = d3.select('#' + this.table + ' tbody').selectAll('tr[style="display: table-row;"]').size();
          $.ajax({
            url : this.config.analytics + '/'+ this.config.uuid,
            type : 'post',
            data :  { 'action' : 'filter', 'target' : key, 'value' : test, 'count' : match },
            cache : false,
            timeout : 20000
          });
        },
        
        filter : function () { 
          var filters = []; // array of test function (one per column)
          this.spec.find("th[data-filter] input").each(
            function (i, e) {
              var input = $(e),
                  key = input.closest('th').attr('data-filter'),
                  val = input.val(),
                  test, model, filterFunc;
              if (key && val && val !== '') {
                test = val.toUpperCase();
                model = _myRowModel[key];
                if (model && model.filter) {
                  filterFunc = function(d) { return model.filter(d, key, test); }
                } else {
                  filterFunc = function(d) { return _filter(d, key, test); }
                }
                filters.push(filterFunc);
              }
            }
          );
          
          d3.select('#' + this.table + ' tbody').selectAll('tr').style('display',
            function (d) {
              var i;
              for (i = 0; i < filters.length; i++) {
                if (!filters[i](d)) {
                  return 'none';
                }
              };
              return 'table-row';
            }
          );
        },
        
        reset : function () {
          // hides sort arrows (does not return to primitive order !)
          $('#' + this.table).find('th').removeClass('ascending').removeClass('descending');
          // clean filters input and show again all rows
          this.spec.find("th[data-filter] input").each( function (i, e) { $(e).val(''); } );
          d3.select('#' + this.table + ' tbody').selectAll('tr').style('display', 'table-row');
        },

        // Replaces row data matching data.Id as row key, fallbacks to data.Email
        updateRow : function ( data ) {
          var uid, email, cells;
          if (data) {
            uid = data.Id;
            email = data.Email;
            d3.select('#' + this.table + ' tbody').selectAll('tr').each(
              function (d, i) {
                if ((uid && (d.Id === uid)) || (email && (d.Email === email))) {
                  // update row cells
                  cells = d3.select(this).data([ data ]).selectAll('td').data(_myEncodeRowFunc);
                  cells.html(_renderCell);
                }
              }
            )
            $('#' + this.table).find('th').removeClass('ascending').removeClass('descending');
          }
        },

        // Prepends a new row with data
        insertRow : function ( data ) {
          if (data) {
            d3.select('#' + this.table + ' tbody')
              .insert('tr', ':first-child')
              .data([ data ])
              .selectAll('td')
              .data(_myEncodeRowFunc)
              .enter()
              .append('td').html(_renderCell);
            $('#' + this.table).find('th').removeClass('ascending').removeClass('descending');
          }
        },

        // Removes a row matching an id
        removeRowById : function ( id ) {
          d3.select('#' + this.table + ' tbody').selectAll('tr').each(
            function (d, i) {
              if (id && (d.Id === id)) {
                cells = d3.select(this).remove();
              }
            }
          )
        },

        // Returns DOM node for row (tr element) matching an id
        getRowById : function ( id ) {
          var res;
          d3.select('#' + this.table + ' tbody').selectAll('tr').each(
            function (d, i) {
              if (id && (d.Id === id)) {
                res = this;
              }
            }
          )
          return res;
        },

        // Interprets JSON Ajax success response protocol
        // By default subscribed to 'axel-save-done' and 'axel-delete-done' from modal editors
        // TODO: implement remove Action
        ajaxSuccessResponse : function (event, editor, command, xhr) {
          var response = JSON.parse(xhr.responseText),
              table, payload;
          if (response.payload) {
            payload = response.payload;
            if (payload.Table === _name) {
              if (payload['Users']) { // FIXME: replace by Rows ?
                if (payload.Action === 'update') {
                  this.updateRow(payload.Users );
                } else if (payload.Action === 'create') {
                  this.insertRow(payload.Users);
                }
              } else {
                xtiger.cross.log('error', _name + ' table received Ajax response w/o Users payload');
              }
            } else {
              xtiger.cross.log('error', _name + ' table dismiss ajax response for ' + payload.Table);
            }
          }
        },

        // Table click event dispatcher based on table model
        handleAction : function (ev) {
          var target = $(ev.target),
              key, modal, uid, src, ctrl, template, wrapper, action,
              GEN = _myRowModel,
              hotspot = ev.target.nodeName.toUpperCase();
          if ((hotspot === 'A') || (hotspot === 'BUTTON')) {
            // 1. find key to identify target editor or action
            uid = d3.select(target.parent().parent().get(0)).data()[0].Id; // tr datum
            key = d3.select(target.parent().get(0)).data()[0].key; // td datum
            editor = GEN[key].editor;
            action = target.attr('data-action');
            if (action) {
              callback = GEN[key].callback[action];
            } else {
              callback = GEN[key].callback;
            }
            // 2. transform editor, load data, show modal
            if (editor) { // shows corresponding modal editor
              src = GEN[key].resource ? GEN[key].resource.replace('$_', uid).replace('$\#', _name) : undefined;
              ctrl = GEN[key].controller ? GEN[key].controller.replace('$_', uid).replace('$\#', _name) : undefined;
              template = GEN[key].template ? GEN[key].template.replace('$_', uid) : undefined;
              if (src.indexOf('$!') !== 0) {
                src = src.replace('$!', d3.select(target.parent().parent().get(0)).data()[0].RemoteLogin);
              }
              wrapper = $axel('#' + editor);
              // src = src + ".xml?goal=" + goal;
              ed = $axel.command.getEditor(editor);
              if (wrapper.transformed()) { // template reuse
                if (template) { // update template and data
                  ed.transform(template, src);
                } else { // just load data (single template editor ?)
                  wrapper.load(src);
                }
                $('#' + editor + ' .af-error').hide();
                $('#' + editor + '-errors').removeClass('af-validation-failed');
                if (wrapper.transformed()) {
                  $('#' + editor + '-modal').modal('show');
                  if (ctrl) {
                    ed.attr('data-src', ctrl);
                  }
                }
              } else { // first time
                if (template) {
                  ed.attr('data-template', template);
                }
                ed.attr('data-src', src);
                ed.transform();
                if (ctrl) {
                  ed.attr('data-src', ctrl);
                }
                if (wrapper.transformed()) {
                  $('#'+ editor).bind('axel-cancel-edit', function() { $('#' + editor + '-modal').modal('hide'); });
                  $('#' + editor + '-modal').modal('show');
                }
              }
              if (!this.modals[editor]) { // registers once Ajax response handler for that modal
                this.modals[editor] = $.proxy(this, "ajaxSuccessResponse");
                $('#' + editor).bind('axel-save-done', this.modals[editor]);
                $('#' + editor).bind('axel-delete-done', this.modals[editor]);
              }
            } else if (GEN[key].open) { //open url action
              target.attr('href', uid); // dynamically sets URL and opens link
              target.click(function (event) { // avoid too much recursion due to recursive clicking on table
                event.stopPropagation();
              });
              target.click();
            } else if (callback) {
              callback(uid, key, target);
            } else if (GEN[key].modal) { // loads content into modal box
              src = GEN[key].resource ? GEN[key].resource.replace('$_', uid).replace('$\#', _name) : undefined;
              modal = $('#' + GEN[key].modal);
              modal.find('.modal-body')
                .html('<p>Loading</p>') // TODO: spinning wheel
                .load(src,
                  function(txt, status, xhr) {
                    if (status !== "success") {
                      modal.html('Error loading content, sorry for the inconvenience');
                    }
                  }
                );
              modal.modal('show');
            }
          }
        },

        // Generates table rows with d3
        execute : function( data, update ) {
          var table = d3.select('#' + this.table).style('display', 'table'),
              rows,
              cells;

          // reset sorting and filters
          this.reset();
          if (!update) {
            // table rows maintenance
            rows = table.select('tbody').selectAll('tr').data(data);
            rows.enter().append('tr');
            rows.exit().remove();

            // cells maintenance
            cells = table.select('tbody').selectAll('tr').selectAll('td').data(_myEncodeRowFunc);
            cells.html(_renderCell); // update
            cells.enter().append('td').html(_renderCell); // create
            cells.exit().remove(); // delete
          } else {
            // FIXME: rewrite using full d3 API (no need for for ?)
            for (var i=0; i < data.length; ++i) {
            	table.select('tbody').append('tr').data( [ data[i] ]).selectAll('td').data(_myEncodeRowFunc).enter().append('td').html(_renderCell);
            }
          }
          return this;
        }
      };
    }(encodeRowFunc, tableRowModel)); // end of prototype generation

    $axel.command.register(name +'-table', kommand, { check : false });
  }

  $axel.command.makeTableCommand = _makeTableCommand;
}());

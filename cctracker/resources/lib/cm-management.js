(function () {

  // User table column models - could be packaged in JSON reponse to localize server-side
  var GENUSER = {
    Name : {
      'yes' : '*',
      'editor' : 'cm-update-person-editor',
      'resource' : 'persons/$_',
      'template' : 'templates/person?goal=update&user=$_',
      ascending : function(a, b) { return d3.ascending(a.Name.LastName, b.Name.LastName); },
      descending :  function(a, b) { return d3.descending(a.Name.LastName, b.Name.LastName); }
    },
    Login : {
      'yes' : '*',
      'no' : '---',
      'editor' : 'cm-update-account-editor',
      'resource' : 'accounts/$_',
      ascending : function(a, b) { var i = a.Login ? a.Login.toUpperCase() : 'ZZZ', j = b.Login ? b.Login.toUpperCase() : 'ZZZ'; return d3.ascending(i, j); },
      descending : function(a, b) { var i = a.Login ? a.Login.toUpperCase() : 'AAA', j = b.Login ? b.Login.toUpperCase() : 'aaa'; return d3.descending(i, j); }
    },
    Access : {
      'yes' : '<b>yes</b>',
      'no' : '<a>create</a>',
      'editor': 'cm-create-account-editor',
      'resource' : 'accounts/$_?goal=create'
    },
    Admin : {
      'yes' : '<b>yes</b> (<a>no<a>)',
      'no' : '<b>no</b> (<a>yes</a>)',
      'role' : 'admin-system',
      'callback' : doRoleChangeAction
    },
    Coach : {
      'yes' : '<b>yes</b> (<a>no<a>)',
      'no' : '<b>no</b> (<a>yes</a>)',
      'role' : 'coach',
      'callback' : doRoleChangeAction
    },
    Action : {
      'yes' : '<a class="btn btn-small" target="_blank">Inspect</a>',
      'open' : '$_'
    }
  };

  // Import table column models - could be packaged in JSON reponse to localize server-side
  // Persists remote login with $! to regenerate rows upon Ajax updating
  var GENIMPORT = {
    Name : { // or RemoteName
      yes : '*',
      editor : 'cm-update-person-editor',
      resource : 'persons/$_/import?table=import&persists=$!',
      template : 'templates/person?goal=update&user=$_'
    },
    RemoteName : { // or Name
      yes : '.',
      no : '-'
    },
    User : {
      yes : 'yes',
      no : '<a>import</a>',
      callback : doImportAction // uses cm-create-person-editor modal
    },
    Login : {
      yes : '*',
      no : '---',
      editor : 'cm-update-account-editor',
      resource : 'accounts/$_?table=import&persists=$!'
    },
    Access : { // or NoAccess
      yes : 'yes',
      no : '<a>create</a>',
      editor: 'cm-create-account-editor',
      resource : 'accounts/$_?goal=create&table=import&persists=$!'
    },    
    NoAccess : { // or Access
      yes : '---',
      no : '---'
    },    
    RemoteLogin : {
      yes : '.',
      no : '---'
    },
    Email : {
      yes : '@',
      no : '---'
    }
  };
  
  // (Generic) generates XML payload for Ajax request
  function genPayloadFor( editor ) {
    return $axel("#cm-" + editor + "-edit").xml();
  }

  // Utility to check Ajax reponse
  function filterPayload( data, name ) {
    if (data.payload && data.payload[name]) {
      return true;
    } else {
      xtiger.cross.log('error', 'bad Ajax response, no ' + name + ' payload');
      return false;
    }
  }

  // Forwards $.ajax errors to application global error handler
  function jqForwardError ( xhr, status, e )  {
    $('#cm-mgt-busy').hide();
    $('body').trigger('axel-network-error', { xhr : xhr, status : status, e : e });
  }

  // heuristics to pretty print person name
  function prettyPrintName( n, id ) {
    var res = '', fn, ln;
    if (n) {
      if (n.LastName) {
        res = n.LastName.toUpperCase() + ' ';
      }
      ln= n.FirstName;
      if (ln) {
        ln = $.trim(ln);
        if (!/[a-z]/.test(ln)) { // all capital
          res += ln.charAt(0).toUpperCase() + ln.substr(1).toLowerCase();
        } else { // already ready
          res += ln.charAt(0).toUpperCase() + ln.substr(1);
        }
      }
    } else {
      res = "Anonymous (" + id + ")";
    }
    return res;
  }

  ////////////////////////
  // User results table //
  ////////////////////////

  // Turns User hash entry into table row (to be aligned with table columns server-side)
  function encodeUserRow( d, encodeCell ) {
    if (d.Name.LastName) {
      d.Name.LastName = d.Name.LastName.toUpperCase();
    }
    var res = [
      encodeCell('Name', prettyPrintName(d.Name, d.Id )),
      encodeCell('Login', d),
      encodeCell('Access', d),
      encodeCell('Admin', d),
      encodeCell('Action', '-')
    ];
    return res;
  }

  // Expects: DB.Table (name of table to redraw), DB.Coaches (rows)
  function submitSearchSuccess ( data, status, xhr ) {
    var DB = (data.Users === undefined || $.isArray(data.Users)) ? data.Users : [ data.Users ];
    $('#cm-mgt-busy').hide();
    if (DB) { // something to show
      $('#no-sample').hide();
      try {
        $axel.command.getCommand('user-table', 'cm-user-results').execute(DB);
      } catch (e) {
        alert('Exception [' + e.name + ' / ' + e.message + '] please contact application administrator !');
      }
    } else { // nothing to show
      $('#no-sample').show();
      d3.selectAll('#cm-' + data.Table + '-results').style('display', 'none');
    }
  }

  function submitSearchUser () {
    var payload = genPayloadFor('user');
    $('#cm-mgt-busy').show();
    $.ajax({
      url : 'management/users/search',
      type : 'post',
      async : false,
      data : payload,
      dataType : 'json',
      cache : false,
      timeout : 50000,
      contentType : "application/xml; charset=UTF-8",
      success : submitSearchSuccess,
      error : jqForwardError
    });
  }

  // DEPRECATED ???
  // Manages Ajax success response for a role change
  function roleCommandSuccess( response, status, xhr ) {
    $('#cm-mgt-busy').hide();
    if (filterPayload(response, 'Users')) {
      $axel.command.getCommand('user-table', 'cm-user-results').updateRow(response.payload.Users);
    }
  }

  // DEPRECATED ???
  // Set/Unset a new role for a user 
  function doRoleChangeAction( uid, key, target ) {
    var role = GENUSER[key].role,
        action = target.text(),
        payload;
    if (action === 'yes') {
      payload = '<Set>' + role + '</Set>';
    }  else {
      payload = '<Unset>' + role + '</Unset>';
    }
    $('#cm-mgt-busy').show();
    $.ajax({
      url : 'management/roles/' + uid,
      type : 'post',
      async : false,
      data : payload,
      dataType : 'json',
      cache : false,
      timeout : 50000,
      contentType : "application/xml; charset=UTF-8",
      success : roleCommandSuccess,
      error : jqForwardError
    });
  }

  //////////////////////////
  // Import results table //
  //////////////////////////

  // Turns User hash entry into table row (to be aligned with table columns server-side)
  // When d.Name and d.Id are defined the user is already a coach match user
  function encodeImportRow( d, encodeCell ) {
    var cname, access;
    // logic to create coach Name column
    // a Name with an Id is also in coach match DB
    if (d.Id !== undefined) {
      cname = encodeCell('Name', d.Name);
      access = encodeCell('Access', d);
    } else {
      cname = encodeCell('RemoteName', d.Name);
      access = encodeCell('NoAccess', '1');
    }
    
    res = [
      cname,
      encodeCell('User', d.Id),
      //encodeCell('Login', d),
      //access,
      //encodeCell('RemoteLogin', d),
      encodeCell('Email', d)
    ];
    return res;
  }

  // Expects: IMPORT.Table (name of table to redraw), IMPORT.Users (rows)
  function submitImportSuccess ( data, status, xhr ) {
    var IMPORT= ((data.Users === undefined) || $.isArray(data.Users)) ? data.Users : [ data.Users ];
    $('#cm-mgt-busy').hide();
    if (IMPORT) { // something to show
      $('#no-sample').hide();
     try {
       $axel.command.getCommand('import-table', 'cm-import-results').execute(IMPORT);
      } catch (e) {
        alert('Exception [' + e.name + ' / ' + e.message + '] please contact application administrator !');
      }
      $('#cm-import-feedback span:eq(0)').text(IMPORT.length);
    } else { // nothing to show
      $('#cm-import-feedback span:eq(0)').text(0);
      d3.selectAll('#cm-import-results').style('display', 'none');
    }
    $('#cm-import-feedback span:eq(1)').text(data.Letter);
    $('#cm-import-feedback').show();
  }

  // FIXME: todo POST request (?)
  function submitImportUser (ev) {
    var _cur = ev.target;
    if ((_cur.nodeName.toUpperCase() === 'A') && ($(_cur).text().charAt(0) !== '[')) {
      $('#cm-import-index a').each(
        function (i, e) {
          var t = $(e).attr('href').substr(1);
          (e === _cur) ? $(e).text('[ ' + t + ' ]') : $(e).text(t);
        } 
        );
      $('#cm-mgt-busy').show();
      $.ajax({
        url : 'management/import?letter=' + $(ev.target).attr('href').substr(1),
        type : 'get',
        async : false,
        dataType : 'json',
        cache : false,
        timeout : 50000,
        success : submitImportSuccess,
        error : jqForwardError
      });
    }
    return false;
  }

  // Opens create user modal pre-filled with user data
  // Sets POST address to create
  function doImportAction( uid, key, target ) {
    var email = d3.select(target.parent().parent().get(0)).data()[0].Email,
        remote, ed;
    if (email) {
      remote = d3.select(target.parent().parent().get(0)).data()[0].RemoteLogin;
      ed =  $axel.command.getEditor('cm-create-person-editor');
      ed.attr('data-src', 'management/import?profile=' + email);
      ed.transform();
      $('#cm-create-person-editor-modal').modal('show');
      ed.attr('data-src', remote ? 'management/import?persists=' + remote : 'management/import');
    } else {
     alert('You cannot import that user because s/he has no e-mail address')
    }
  }

  // Manages external modal window to add a new user
  // either from Add a new user button of from doImportAction
  function saveCommandSuccess(event, editor, command, xhr) {
    var response = JSON.parse(xhr.responseText),
        table = response.payload ? response.payload.Table : undefined;
    $axel.command.getCommand(table + '-table', 'cm-' + table + '-results').ajaxSuccessResponse(event, editor, command, xhr);
  }

  function init() {
    // commands
    //$('#cm-user-button').click(submitSearchUser);
    $('#cm-import-index').click(submitImportUser);
    // modal editors
    $('#cm-create-person-editor').bind('axel-save-done', saveCommandSuccess);
    // login pane
    /*$('a[data-toggle="tab"]').on('show', function (e) {
        var jnode = $(e.target),
            pane= $(jnode.attr('href')),
            url = jnode.attr('data-src'); 
        if (url && url.charAt(0) !== '#') {
          pane.load(url, function(txt, status, xhr) { if (status !== "success") { pane.html('Impossible to load content'); }  });
        }
    });*/
  }

  jQuery(function() { init(); });

  // records new commands before page ready handler
  //$axel.command.makeTableCommand('user', encodeUserRow, GENUSER);
  $axel.command.makeTableCommand('import', encodeImportRow, GENIMPORT);
}());

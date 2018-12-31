(function () {

  function init() {
    $('.nav-tabs a').click(function (e) {
        var jnode = $(this),
            pane= $(jnode.attr('href')),
            url = jnode.attr('data-src');
        pane.html('<p class="xcm-busy" style="height:32px"><span style="margin-left: 48px">Loading in progress...</span></p>');
        jnode.tab('show'); 
        pane.load(url, function(txt, status, xhr) {
          if (status !== "success") { pane.html('Impossible to load the page, maybe your session has expired, please reload the page to login again'); }
            // clicking on input within table cell triggers tablesort without getting focus on 
            // inserted input so clicking on input shall put focus and does not fire tablesorter
            $('[name*="users"]').find('input').each(function(i,e) {
              $(e).first().click(function( event ) {
                $(this).focus()
                event.stopPropagation();
              });
            })
          $('#results-export').children('a').first().click(function() {
            return ExcellentExport.severalExcel(this, document.getElementsByName('users'), "Users");
          });
          $('#results-export').children('a').eq(1).click(function() {
            return ExcellentExport.csv(this, $('[name="users"]').get(0), ",");
          });
          $('#results-export').children('a').eq(2).click(function() {
            $('#user-filter').val('')
            $('#country-filter').val('')
            $('#role-filter').val('')
            $('#user-filter').keyup();
            return ;
          });
        });
    });

    $('a[data-toggle="tab"]').on('show', function (e) {
        var jnode = $(e.target),
            pane= $(jnode.attr('href')),
            url = jnode.attr('data-src');
        if (url.charAt(0) !== '#') {
          pane.load(url, function(txt, status, xhr) { if (status !== "success") { pane.html('Impossible to load the page'); }  });
        }
    });    
    // person editing modal
    $('#c-pane-users').parent().click(showItemDetails);
    $('#c-pane-users').bind('keyup', filterUsers);
  }

  // Opens up modal window, loads it pre-defined template, loads target data inside it
  function showItemDetails (ev) {
    var target = $(ev.target),
        src, key, wrapper, ed, 
        goal = 'update';
    // 1. find data source and key to identify target editor
    src = target.attr('data-person');
    if (src) {
      key = 'person';
    } else {
      src = target.attr('data-profile');
      if (src) {
        key = 'profile';
      }
    }
    // 2. transform editor, load data, show modal
    if (src) {
      wrapper = $axel('#c-' + key + '-editor');
      src = src + ".xml?goal=" + goal;
      ed = $axel.command.getEditor('c-' + key + '-editor');
      if (wrapper.transformed()) { // reuse
        if (key === 'person') {
          wrapper.load('<Reset><External/><Member/></Reset>');
        } else { // assuming profile
          wrapper.load('<Reset><Roles><Role/></Roles><Static><Role/></Static></Reset>'); // TODO: fix ed.empty()
        }
        $('#c-' + key + '-editor .af-error').hide();
        $('#c-' + key + '-editor-errors').removeClass('af-validation-failed');
        ed.attr('data-src', src);
        wrapper.load(src);
        if (wrapper.transformed()) {
          $('#c-' + key + '-editor-modal').modal('show');
        }
      } else { // first time
        ed.attr('data-src', src);
        ed.transform();
        if (wrapper.transformed()) {
          $('#c-'+ key + '-editor').bind('axel-cancel-edit', function() { $('#c-' + key + '-editor-modal').modal('hide'); });
          $('#c-' + key + '-editor-modal').modal('show');
        }
        $('#c-' + key + '-editor').bind('axel-save-done', itemSaveDone );
      }
    } 
  }

  // Return true if e contains name str
  function filterName ( e, str ) {
    return (str.length === 0 || e.textContent.toUpperCase().indexOf(str) !== -1);
  }

  // Return true if e contains role urn
  // Pre-condition: Roles in column #2
  function filterRole(e, str) {
    return (str.length === 0 || $(e).closest('tr').find('td:nth-child(2)').text().toUpperCase().indexOf(str) !== -1);
  }

  // Filters users table rows applying fn and rn criterias
  function filterUsers (ev) {
    var t = $(ev.target), ufn, urn;
    
    if (t.attr('id') === 'user-filter' || t.attr('id') === 'role-filter') {
      ufn = $('#user-filter').val().toUpperCase();
      urn = $('#role-filter').val().toUpperCase()

      $("span.fn").each( function (i,e) {
        if (filterName(e, ufn) && filterRole(e, urn)) {
          $(e).closest('tr').show();
        }
        else {
          $(e).closest('tr').hide();
        }
      });
    }
  }

  // Closes edit modal window and fakes an event to reload item details window content
  function itemSaveDone (ev, editor, source, xhr) {
    var key;
    key = $('Payload', xhr.responseXML).attr('Key') || $('Payload', xhr.responseXML).attr('Table'); // two procotols
    if ((key === 'Person') || ($('Person', xhr.responseXML).attr('Update') === 'y')) {
      key = 'person'; // trick to share person controller with search.js
    }
    $('#c-' + key + '-editor-modal').modal('hide'); // should make display modal appear
    if (key === 'profile')
      reportProfileUpdate(xhr.responseXML);
    else if (key === 'person')
      reportUserUpdate(xhr.responseXML);
  }
  
  function reportUserUpdate(response) {
    var id = $('Id', response).text(),
        remote = $('Remote', response).text(),
        email = $('Email', response).text(),
        label;
    $("a[data-person$='/" + id + "']").text(remote || email || id);
    // TODO: implement Personalities > Pers > Email to update Contacts Email (SMEIMKT-1097)
  }

  function reportProfileUpdate(response) {
    var id = $('Id', response).text(), roles = [], pers = "", email = "";
    $('Role', response).each( function() { roles.push($(this).text()) })
    $('Pers', response).each( function() { pers += '<span class="fn" style="display:block">' + $('LastName', this).text() + ' '+ $('FirstName', this).text() + ' (' + $(this).attr('Enterprise')  + ')' + '</span>'})
    $('Pers', response).each( function() { email += '<span style="display:block">' + $('Email', this).text() + '</span>'})
    var cell = $("a[data-profile$='/" + id + "']"),
        row = cell.closest('tr');
    cell.html(roles.join('<br/>'));
    row.find('td:nth-child(3)').html(pers);
    row.find('td:nth-child(4)').html(email);
  }

  jQuery(function() { init(); });
}());

(function () {
  var _lang,
      _counter;

  function saveTranslations () {
    var url, payload, 
        prefix = '/exist',
        res = $('*[loc][data-translate]').map(function(i,e) {
          return '<Translation key="' + $(e).attr('loc') + '">' + $(e).attr('data-translate') + '</Translation>';
          });
    if (res.length > 0) {
      payload = '<Translations lang="' + _lang + '">' + res.toArray().join('') + '</Translations>';
      if (window.location.pathname.slice(0, prefix.length) === prefix) {
        url = '/exist/projects/cctracker/dictionary';
      } else {
        url = '/dictionary'
      }
      $.ajax({
        url : url,
        type : 'post',
        data : payload,
        dataType : 'xml',
        cache : false,
        timeout : 10000,
        contentType : "application/xml; charset=UTF-8",
        success : function() { alert('Traductions enregistrées') },
        error : function() { alert('Erreur à la sauvegarde') }
        });
    } else {
      alert('Traduisez au moins 1 terme !');
    }
  }

  function stopTranslations () {
    window.location.href=window.location.pathname + '?t=off';
  }

  function init() {
    var loc = $('*[loc]'),
        lang,
        label = { 'fr': 'Français', 'de' : 'Allemand' };

    if (loc.length > 0) {
      lang = window.location.search.match(/=(\w\w)$/);
      if (lang) {
        _lang = (lang[1] === 'de') ? 'de' : 'fr';
      }
      loc.click(function() {
        var txt = prompt('Traduction de “' + $(this).text() + '” (vers “' + label[_lang] + '”) ?', $(this).text());
        $(this).text(txt).attr('data-translate',txt);
        _counter.text("Sauver les traductions (" + $('*[loc][data-translate]').size() + ")");
        return false;
        });
      _counter = $('<button style="position:fixed;left:20px;top:10px;z-index:1000" id="c-translator" class="btn">Sauver les traductions</button>')
      $('body').append(_counter);
      $('body').append('<button style="position:fixed;left:20px;top:40px;z-index:1000" class="btn" id="c-translator-off">Arrêter les traductions</button>');
      $('#c-translator').click(saveTranslations);
      $('#c-translator-off').click(stopTranslations);
    }
  }

  jQuery(function() { init(); });
}());

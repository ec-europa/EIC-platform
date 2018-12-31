(function () {

  // results table in /enterprises search
  var GENCOMPANIES = {
    Name : {
      yes : '*',
      open : 'enterprises/$_',
      ascending : function(a, b) { return d3.ascending(a.Name, b.Name); },
      descending :  function(a, b) { return d3.descending(a.Name, b.Name); }
    },
    Town : {
      yes : '.'
    },
    Country : {
      yes : '.'
    },
    Size : {
      yes : '.'
    },
    Nace : {
      yes : '.'
    },
    Markets : {
      yes : '.'
    },
    Team : {
      yes : '.'
    }
  };
  
  var GENEVENTS = {
    Name : {
      yes : '.',
      //open : 'enterprises/$.CompanyId',
      ascending : function(a, b) { return d3.ascending(a.Name, b.Name); },
      descending :  function(a, b) { return d3.descending(a.Name, b.Name); }
    },
    Event : {
      yes : '.'
    },
    Status : {
      yes : '*',
      open : 'events/$.CompanyId/form/$.EventId'
    }
  };

  // results table in /enterprises/import search
  var GENIMPORTS = {
    Name : {
      yes : '*',
      open : '$_',
      ascending : function(a, b) { return d3.ascending(a.Name, b.Name); },
      descending :  function(a, b) { return d3.descending(a.Name, b.Name); }
    },
    Outcome : {
      yes : '.'
    },
    Notes : {
      yes : '.'
    }
  };

  // results table in /teams search
  var GENTOKENS = {
    Name : {
      yes : '*',
      open : 'teams/$.CompanyId'
    },
    Company : {
      yes : '*',
      open : 'teams/$.CompanyId',
      ascending : function(a, b) { return d3.ascending(a.Company, b.Company); },
      descending :  function(a, b) { return d3.descending(a.Company, b.Company); }
    },
    Role : {
      yes : '.'
    },
    CreatedBy : {
      yes : '.',
      no : '<i>import</i>'
    },
    Access : {
      yes : '.'
    },
    Action : {
      yes : '.',
      ajax : {
        'allocate' : {
          url : 'teams/$.CompanyId/token/$.PersonId',
          payload: '<Allocate/>'
        },
        'withdraw' :  {
          url : 'teams/$.CompanyId/token/$.PersonId',
          payload: '<Withdraw/>'
        },
        'reject' :  {
          url : 'teams/$.CompanyId/token/$.PersonId',
          payload: '<Reject/>'
        }
      }
    }
  };

  // results table in /teams search
  var GENINVESTORS = {
    Name : {
      yes : '.',
      //open : 'admissions/investors/$.PersonId'
      ascending : function(a, b) { return d3.ascending(a.Name, b.Name); },
      descending :  function(a, b) { return d3.descending(a.Name, b.Name); }
    },
    Company : {
      yes : '*',
      open : 'admissions/$.AdmissionId',
      ascending : function(a, b) { return d3.ascending(a.Company, b.Company); },
      descending :  function(a, b) { return d3.descending(a.Company, b.Company); }
    },
    Role : {
      yes : '.'
    },
    CreatedBy : {
      yes : '.',
      no : '<i>import</i>'
    },
    Access : {
      yes : '.'
    },
    Admission : {
        yes : '.',
        no : '<i>error</i>'
    },
    Action : {
      yes : '.',
      ajax : {
        'accredit' : {
          url : 'admissions/investors/$.PersonId/accredit',
          payload: '<Accredit/>'
        },
        'block' :  {
          url : 'admissions/investors/$.PersonId/accredit',
          payload: '<Block/>'
        },
        'unblock' :  {
          url : 'admissions/investors/$.PersonId/accredit',
          payload: '<Unblock/>'
        },
        'reject' :  {
          url : 'admissions/investors/$.PersonId/accredit',
          payload: '<Reject/>'
        },
        'unreject' :  {
          url : 'admissions/investors/$.PersonId/accredit',
          payload: '<Unreject/>'
        }
      }
    }
  };
  
  // results table in /teams search
  var GENENTRY = {
    Name : {
      yes : '.',
      //open : 'admissions/entry/$.PersonId'
      ascending : function(a, b) { return d3.ascending(a.Name, b.Name); },
      descending :  function(a, b) { return d3.descending(a.Name, b.Name); }
    },
    Company : {
      yes : '*',
      open : 'admissions/$.AdmissionId',
      ascending : function(a, b) { return d3.ascending(a.Company, b.Company); },
      descending :  function(a, b) { return d3.descending(a.Company, b.Company); }
    },
    Role : {
      yes : '.'
    },
    CreatedBy : {
      yes : '.',
      no : '<i>import</i>'
    },
    OrganisationStatus : {
      yes : '.'
    },
    Date : {
      yes : '.'
    },
    OrganisationTypes : {
      yes : '.'
    },
    Access : {
      yes : '.'
    },
    Admission : {
        yes : '.',
        no : '<i>error</i>'
    },
    Action : {
      yes : '.',
      ajax : {
        'accredit-all' : {
          url : 'admissions/entry/$.PersonId/accredit',
          payload: '<Accredit-all/>'
        },
        'block' :  {
          url : 'admissions/entry/$.PersonId/accredit',
          payload: '<Block/>'
        },
        'unblock' :  {
          url : 'admissions/entry/$.PersonId/accredit',
          payload: '<Unblock/>'
        },
        'reject-all' :  {
          url : 'admissions/entry/$.PersonId/accredit',
          payload: '<Reject-all/>'
        },
        'unreject-all' :  {
          url : 'admissions/entry/$.PersonId/accredit',
          payload: '<Unreject-all/>'
        }
      }
    }
  };  
  

  // results table in /teams search
  var GENMEMBERS = {
    Name : {
      yes : '*',
      open : 'teams/$.CompanyId'
    },
    Company : {
      yes : '*',
      open : 'enterprises/$.CompanyId',
      ascending : function(a, b) { return d3.ascending(a.Company, b.Company); },
      descending :  function(a, b) { return d3.descending(a.Company, b.Company); }
    },
    Role : {
      yes : '.'
    },
    CreatedBy : {
      yes : '.',
      no : '<i>import</i>'
    },
    Access : {
      yes : '.'
    },
    Action : {
      yes : '.',
      ajax : {
        'accredit' : {
          url : 'teams/$.CompanyId/members/$.MemberId/accredit',
          payload: '<Accredit/>'
        },
        'block' :  {
          url : 'teams/$.CompanyId/members/$.MemberId/accredit',
          payload: '<Block/>'
        },
        'reject' :  {
          url : 'teams/$.CompanyId/members/$.MemberId/accredit',
          payload: '<Reject/>'
        }
      }
    }
  };

  // results table in /teams search
  var GENUNAFFILIATEDS = {
    CreatedBy : {
      yes : '.',
      no : '<i>import</i>'
    },
    Access : {
      yes : '.'
    }
  };

  // Turns Company hash entry into companies table row
  function encodeCompanyRow( d, encodeCell ) {
    // 1. formats model data
    // 2. generates array for cell display
    var res = [
      encodeCell('Name', d),
      d.Town,
      d.Country,
      d.Size,
      d.Nace,
      d.Markets,
      d.Team
    ];
    return res;
  }  

  // Turns Imported hash entry into imports table row
  function encodeImportRow( d, encodeCell ) {
    // 1. formats model data
    // 2. generates array for cell display
    var res = [
      d.Id ? encodeCell('Name', d) : d.Name,
      d.Outcome,
      d.Notes
    ];
    return res;
  }

  // could be done serve-side but since we need it to generate buttons...
  function decodeAccessLevel( level ) {
    var res;
    if (level === '1' ) {
      res = 'Pending';
    } else if (level === '2' ) {
      res = 'Rejected';
    } else if (level === '3' ) {
      res = 'Authorized';
    } else if (level === '4' ) {
      res = 'Blocked';
    } else if (level === '99' ) {
      res = '<i>unknown</i>';
    }
    return res;
  }

  // Based on AdmissionStatusRef
  function decodeAdmission( level ) {
    var res;
    if (level === '1' ) {
      res = 'Draft';
    } else if (level === '2' ) {
      res = 'Submitted';
    } else if (level === '3' ) {
      res = 'Rejected';
    } else if (level === '4' ) {
      res = 'Authorized';
    } else if (level === '98' ) {//obsolete formular
      res = 'Submitted';
    }else if (level === '99' ) {
      res = '<i>unknown</i>';
    }
    return res;
  }

  // generates buttons
  function decodeTokenAccessLevelAction( level ) {
    var res;
    if (level === '1' ) {
      res = '<button class="ecl-button ecl-button--call" data-action="allocate">Allocate</button> <button class="ecl-button ecl-button--call" data-action="reject">Reject</button>';
    } else if (level === '2' || level === '4' || level === '5' || level === '6' || level === undefined) {
      res = '<button class="ecl-button ecl-button--call" data-action="allocate">Allocate</button>';
    } else if (level === '3' ) {
      res = '<button class="ecl-button ecl-button--call" data-action="withdraw">Withdraw</button>';
    } else if (level === '-1' ) {
      res = 'accredit first'
    }
    return res;
  }

  // could be done serve-side but since we need it to generate buttons...
  function decodeTokenAccessLevel( level ) {
    var res;
    if (level === '1' ) {
      res = 'Pending';
    } else if (level === '2' ) {
      res = 'Rejected';
    } else if (level === '3' ) {
      res = 'Allocated';
    } else if (level === '4' ) {
      res = 'Withdrawn';
    } else if (level === '5' ) {
      res = 'Transferred';
    } else if (level === '6' ) {
      res = 'Deleted';
    }
    return res;
  }

  // generates buttons
  function decodeAccessLevelAction( level ) {
    var res;
    if (level === '1' ) {
      res = '<button class="ecl-button ecl-button--call" data-action="accredit">Accredit</button> <button class="ecl-button ecl-button--call" data-action="reject">Reject</button>';
    } else if (level === '2' ) {
      res = '';
    } else if (level === '3' ) {
      res = '<button class="ecl-button ecl-button--call" data-action="block">Block</button>';
    } else if (level === '4' ) {
      res = '';
    } else if (level === '99' ) {
      res = '';
    }
    return res;
  }
  
  // Investors have 3 access levels
  // Pending - 1
  // Block - 4
  // Authorized - 3
  // 99 = unknow
  function decodeInvestorAction( level, admission ) {
    var res;
    if (level === '1' ) {
        if (admission === '2') {
            // Pending Investor and Submitted admission
            res = '<button class="ecl-button ecl-button--call" data-action="accredit">Accredit</button> <button class="ecl-button ecl-button--call" data-action="reject">Reject</button> <button class="ecl-button ecl-button--call" data-action="block">Block</button>';
        }
        else if (admission === '3') {
            // Pending Investor and Rejected admission
            res = '<button class="ecl-button ecl-button--call" data-action="block">Block</button> <button class="ecl-button ecl-button--call" data-action="unreject">Unreject</button>';
        }
        else if (admission === '1') {
            // Pending Investor and Draft admission
            res = '<button class="ecl-button ecl-button--call" data-action="block">Block</button>';
        }
        else res = '';
    } else if (level === '2' ) {
      res = '';
    } else if (level === '3' ) {
       if (admission === '2') {
            // Authorized Investor and Submitted admission
            res = '<button class="ecl-button ecl-button--call" data-action="block">Block</button>';
        }
        else if (admission === '3') {
            // Authorized Investor and Rejected admission
            res = '<button class="ecl-button ecl-button--call" data-action="block">Block</button>';
        }
        else
        res = '<button class="ecl-button ecl-button--call" data-action="block">Block</button>';
    } else if (level === '4' ) {
      res = '<button class="ecl-button ecl-button--call" data-action="unblock">Unblock</button>';
    } else if (level === '99' ) {
      res = '';
    }

    //res = '<button class="btn" data-action="accredit">accredit</button> <button class="btn" data-action="reject">reject</button> <button class="btn" data-action="unreject">unreject</button> <button class="btn" data-action="block">block</button> <button class="btn" data-action="unblock">unblock</button>';
    return res;
  }


  
  // Entries have 3 access levels
  // Pending - 1
  // Block - 4
  // Authorized - 3
  // 99 = unknow
  function decodeEntryAction( level, admission, deprecated ) {
    var res;
    if (deprecated) {
        res = 'n/a';
    } else if (level === '1' ) {
        if (admission === '2') {
            // Pending User and Submitted admission
            res = '<button class="ecl-button ecl-button--call" data-action="accredit-all">Accept all</button> <button class="ecl-button ecl-button--call" data-action="reject-all">Reject all</button> <button class="ecl-button ecl-button--call" data-action="block">Block</button>';
        }
        else if (admission === '1')  {
            // Pending User and Draft/Rejected admission
            res = '<button class="ecl-button ecl-button--call" data-action="block">Block</button>';
        }
        else if (admission === '3')  {
            // Pending User and Draft/Rejected admission
            res = '<button class="ecl-button ecl-button--call" data-action="block">Block</button> <button class="ecl-button ecl-button--call" data-action="unreject-all">Unreject all</button>';
        }
        else if (admission === '98') {
            // Submitted admission and obsolete formular
            res = '<button class="ecl-button ecl-button--call" data-action="reject-all">Reject obsolete form</button> <button class="ecl-button ecl-button--call" data-action="block">Block</button>';
        }
        else res = '';
    } else if (level === '2' ) {
      res = '';
    } else if (level === '3' ) {
       if (admission === '2') {
            // Authorized User and Submitted admission
            res = '<button class="ecl-button ecl-button--call" data-action="block">Block</button>';
        }
        else if (admission === '3') {
            // Authorized User and Rejected admission
            res = '<button class="ecl-button ecl-button--call" data-action="block">Block</button>';
        }
        else
        res = '<button class="ecl-button ecl-button--call" data-action="block">Block</button>';
    } else if (level === '4' ) {
      res = '<button class="ecl-button ecl-button--call" data-action="unblock">Unblock</button>';
    } else if (level === '99' ) {
      res = '';
    }
    return res;
  }

  // Turn token sample into tokens allocation table row
  function encodeTokenRow( d, encodeCell ) {
    // 1. formats model data
    // 2. generates array for cell display
    var res = [
      d.CurToken,
      d.Key,
      d.EULogin,
      d.Company ? encodeCell('Company', d) : d.Company,
      d.PO,
      encodeCell('CreatedBy', d),
      d.Role,
      decodeTokenAccessLevel(d.Access),
      encodeCell('Action', decodeTokenAccessLevelAction(d.Access))
    ];
    return res;
  }

  // Turn investor sample into investors accreditation table row
  function encodeInvestorRow( d, encodeCell ) {
    // 1. formats model data
    // 2. generates array for cell display
    var res = [
      encodeCell('Name', d),
      d.Key,
      d.Company ? encodeCell('Company', d) : d.Company,
      encodeCell('CreatedBy', d),
      d.Role,
      decodeAccessLevel(d.Access),
      decodeAdmission(d.Admission),
      encodeCell('Action', decodeInvestorAction(d.Access, d.Admission))
    ];
    return res;
  }
  
    // Turn entry sample into entry accreditation table row
  function encodeEntryRow( d, encodeCell ) {
    // 1. formats model data
    // 2. generates array for cell display
    var res = [
      encodeCell('CreatedBy', d),
      encodeCell('Name', d),
      d.Key,
      d.Company ? encodeCell('Company', d) : d.Company,
      
      d.OrganisationTypes,
      d.OrganisationStatus,
      d.Date,
      decodeAdmission(d.Admission),
      decodeAccessLevel(d.Access),
      encodeCell('Action', decodeEntryAction(d.Access, d.Admission, d.Deprecated))
    ];
    return res;
  }

  // Turns member sample into members accreditation table row
  function encodeMemberRow( d, encodeCell ) {
    // 1. formats model data
    // 2. generates array for cell display
    var res = [
      encodeCell('Name', d),
      d.Key,
      d.Company ? encodeCell('Company', d) : d.Company,
      d.PO,
      encodeCell('CreatedBy', d),
      d.Role,
      decodeAccessLevel(d.Access),
      encodeCell('Action', decodeAccessLevelAction(d.Access))
    ];
    return res;
  }

  // Turns unaffiliated user sample into table row
  function encodeUnaffiliatedRow( d, encodeCell ) {
    // 1. formats model data
    // 2. generates array for cell display
    var res = [
      d.Name,
      d.Key,
      encodeCell('CreatedBy', d),
      d.Role,
      decodeAccessLevel(d.Access)
    ];
    return res;
  }

  function encodeEventRow( d, encodeCell ) {
    // 1. formats model data
    // 2. generates array for cell display
    var res = [
      d.Event,
      encodeCell('Name', d),
      d.Country,
      d.Acronym,
      encodeCell('Status', d),
      d.LastChange
    ];
    return res;
  }

  function init() {
    // hide summaries and result tables
    $('button[data-command="table"]').bind('table-load', function () { $("*[id$='-summary']").hide(); $("*[id$='-results']").hide(); });
     $axel('#editor').load('<Foo><AccreditationTypeRef>1</AccreditationTypeRef></Foo>');
  }

  jQuery(function() { init(); });
  
  // records new commands before page ready handler
  $axel.command.makeTableCommand('tokens', encodeTokenRow, GENTOKENS);
  $axel.command.makeTableCommand('investors', encodeInvestorRow, GENINVESTORS);
  $axel.command.makeTableCommand('entries', encodeEntryRow, GENENTRY);
  $axel.command.makeTableCommand('companies', encodeCompanyRow, GENCOMPANIES);
  $axel.command.makeTableCommand('imports', encodeImportRow, GENIMPORTS);
  $axel.command.makeTableCommand('members', encodeMemberRow, GENMEMBERS);
  $axel.command.makeTableCommand('unaffiliated', encodeUnaffiliatedRow, GENUNAFFILIATEDS);
  $axel.command.makeTableCommand('events', encodeEventRow, GENEVENTS);
  $axel.command.makeTableCommand('officers', encodeImportRow, GENIMPORTS);
 
}());

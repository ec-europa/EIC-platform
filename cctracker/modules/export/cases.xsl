<?xml version="1.0" encoding="UTF-8"?>

<!-- CCTRACKER - EIC Case Tracker Application

     Author: Stéphane Sire <s.sire@opppidoc.fr>

     Cases exportation facility

     April 2015 - European Union Public Licence EUPL
  -->

<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site"
  xmlns:xt="http://ns.inria.org/xtiger"
  xmlns="http://www.w3.org/1999/xhtml">

  <!-- TODO: add <site:title> for window title when skin handles pure text() -->
  <xsl:template match="/">
    <site:view skin="date axel">
      <site:window><title>Call <xsl:value-of select="Cases/@Call"/> Phase <xsl:value-of select="Cases/@Phase"/> export</title></site:window>
      <site:content><xsl:apply-templates select="Cases | Error"/></site:content>
    </site:view>
  </xsl:template>

  <xsl:template match="Error">
    <p class="text-error"><xsl:value-of select="."/></p>
  </xsl:template>

  <xsl:template match="Cases">
    <h1>Batch Cases Signature and Notification</h1>
    <div id="results-export">Export <a download="cases.xls" href="#" class="export">excel</a> <a download="cases.csv" href="#" class="export">csv</a></div>

    <xsl:variable name="signed"><xsl:value-of select="count(Case[Date != ''])"/></xsl:variable>
    <xsl:variable name="total1"><xsl:value-of select="count(Case[SN[. != '']])"/></xsl:variable>
    <xsl:variable name="total2"><xsl:value-of select="count(Case[KN[. != '']])"/></xsl:variable>
    <xsl:variable name="total3"><xsl:value-of select="count(Case[KAM[. != '']])"/></xsl:variable>
    <xsl:variable name="total4"><xsl:value-of select="count(Case[NA])"/></xsl:variable>
    <xsl:variable name="total5"><xsl:value-of select="count(Case[A/CP[@Date != 'pending']])"/></xsl:variable>
    <xsl:variable name="total6"><xsl:value-of select="count(Case[A/CP[@Date = 'pending']])"/></xsl:variable>
    <xsl:variable name="total7"><xsl:value-of select="sum(Case/A/CP[. != ''])"/></xsl:variable>
    <xsl:variable name="total"><xsl:value-of select="count(Case)"/></xsl:variable>

    <div class="row-fluid">
      <div class="span6">
    <table class="table table-bordered">
      <caption style="margin:20px 0 10px;text-align:left"><b>Summary</b><xsl:apply-templates select="@Call"/>, generated at <xsl:value-of select="substring(/Cases/@Date, 12, 5)"/> on <xsl:value-of select="substring(/Cases/@Date, 1, 10)"/></caption>
      <thead>
      <tr>
        <th/>
        <th>Total</th>
        <th>% of signed Grants</th>
        <th>% of total</th> 
      </tr>
      </thead>
      <tbody>
      <tr>
        <td>Number of Cases</td>
        <td><xsl:value-of select="$total"/></td>
        <td/>
        <td/>
      </tr>
      <tr>
        <td>Total number of signed Grants</td>
        <td><xsl:value-of select="$signed"/></td>
        <td/>
        <td><xsl:value-of select="format-number($signed div $total, '##.#%')"/></td>
      </tr>
      <tr>
        <td>SME notifications sent</td>
        <td><xsl:value-of select="$total1"/></td>
        <td><xsl:value-of select="format-number($total1 div $signed, '##.#%')"/></td>
        <td><xsl:value-of select="format-number($total1 div $total, '##.#%')"/></td>
      </tr>
      <tr>
        <td>KAM notifications sent</td>
        <td><xsl:value-of select="$total2"/></td>
        <td><xsl:value-of select="format-number($total2 div $signed, '##.#%')"/></td>
        <td><xsl:value-of select="format-number($total2 div $total, '##.#%')"/></td>
      </tr>
      <tr>
        <td>KAM assigned</td>
        <td><xsl:value-of select="$total3"/></td>
        <td><xsl:value-of select="format-number($total3 div $signed, '##.#%')"/></td>
        <td><xsl:value-of select="format-number($total3 div $total, '##.#%')"/></td>
      </tr>
      <tr>
        <td>Needs Analysis dates recorded</td>
        <td><xsl:value-of select="$total4"/></td>
        <td><xsl:value-of select="format-number($total4 div $signed, '##.#%')"/></td>
        <td><xsl:value-of select="format-number($total4 div $total, '##.#%')"/></td>
      </tr>
      <tr>
        <td>Coaching plans submitted</td>
        <td><xsl:value-of select="$total5"/></td>
        <td><xsl:value-of select="format-number($total5 div $signed, '##.#%')"/></td>
        <td><xsl:value-of select="format-number($total5 div $total, '##.#%')"/></td>
      </tr>
      <tr>
        <td>Coaching plans pending </td>
        <td><xsl:value-of select="$total6"/></td>
        <td><xsl:value-of select="format-number($total6 div $signed, '##.#%')"/></td>
        <td><xsl:value-of select="format-number($total6 div $total, '##.#%')"/></td>
      </tr>
      <tr>
        <td>Total hours of coaching</td>
        <td><xsl:value-of select="$total7"/> H</td>
        <td/>
        <td/>
      </tr>
      </tbody>
    </table>
    </div>
    <div class="c-menu-scope span6 noprint" style="border: solid 1px lightgray">
      <div id="editor" data-template="#" style="padding:10px">
        <p><b>Parameters</b></p>
        <p>
          First Name : <xt:use types="input" param="class=span" label="FirstName"><xsl:value-of select="Settings/DefaultEmailSignature/FirstName/text()"/></xt:use>
        </p>
        <p>
          Last Name : <xt:use types="input" param="class=span" label="LastName"><xsl:value-of select="Settings/DefaultEmailSignature/LastName/text()"/></xt:use>
        </p>
        <p>
          From : <xt:use types="input" param="class=span" label="From"><xsl:value-of select="Settings/DefaultEmailReplyTo/text()"/></xt:use>
        </p>
        <p>
          Grant signature date : <xt:use types="input" label="Date" param="type=date;date_region=en;date_format=ISO_8601;class=year;filter=optional"></xt:use>
        </p>        
      </div>
      <!-- <p style="text-align:center"><button class="btn" data-command="save c-inhibit" data-save-flags="silentErrors" data-target="editor" data-src="assign.xml">Assign</button></p> -->
    </div>
    </div>

    <table id="results" class="table table-bordered signature">
      <caption style="margin:20px 0 10px;text-align:left"><b><xsl:value-of select="count(Case)"/> Cases with signed Grant</b><xsl:apply-templates select="@Call"/>, generated by <xsl:value-of select="@User"/> at <xsl:value-of select="substring(/Cases/@Date, 12, 5)"/> on <xsl:value-of select="substring(/Cases/@Date, 1, 10)"/><br/>
        <span class="text-info">Click on a column header to sort the table; KAM notification (Grant Notification email) has been discontinued since february 2016</span></caption>
      <thead>
        <tr>
          <th>No</th>
          <th>Country</th>
          <xsl:if test="@Call = 'all'">
            <th>Phase</th>
            <th>Cut-off</th>
          </xsl:if>
          <th>Acronym</th>
          <th>Project ID</th>
          <th>Signing Date</th>
          <th>KAM</th>
          <th>SME notification</th>
          <th><del>KAM notification</del> (<i>discontinued</i>)</th>
          <th>Needs Analysis date recorded</th>
          <xsl:if test="@Call = 'all'">
            <th>Case status</th>
            <th>To do status</th>
          </xsl:if>
          <th>Coach</th>
          <th>Coaching plan submitted</th>
          <th>Coach contract</th>
          <th>Pool number</th>
          <xsl:if test="@Call = 'all'">
            <th>Coaching days</th>
            <th>Coaching status</th>
            <th>KAM e-mail</th>
            <th>Coach e-mail</th>
            <th>Project officer e-mail</th>
          </xsl:if>
        </tr>
      </thead>
      <tbody>
        <xsl:apply-templates select="Case"/>
      </tbody>
    </table>
    <xsl:if test="@Call = 'all'">
<script type="text/javascript">
// decode phase
$('#results tr > td:nth-child(3)').each( function (i, e) { var n = $(e); n.text( n.text() === '1' ? 'I' : 'II' ); } ) 
// decode case status
var cstatus = {
'1' : 'EEN assignment',
'2' : 'KAM assignment',
'3' : 'Needs analysis',
'9' : 'On hold',
'10' : 'No coaching'
};
$('#results tr > td:nth-child(12)').each( function (i, e) { var n = $(e); n.text( cstatus[n.text()] ); } ) 
// decode activity status
var astatus = {
'1' : 'Coach assignment',
'2' : 'Coaching plan',
'3' : 'Consultation',
'4' : 'Coach contracting',
'5' : 'Coaching report',
'6' : 'KAM report',
'7' : 'Report approval',
'8' : 'SME feedback',
'9' : 'Rejected',
'10' : 'Closed',
'11' : 'Evaluated'
};
// decode todo
$('#results tr > td:nth-child(19)').each( function (i, e) { var n = $(e); n.text( astatus[n.text()] ); } )
var todo = { '1' : 'EEN Consortium not assigned', '2' : 'Grant signature date missing', '3' : 'KAM not assigned', '4' : 'First SME contact not made', '5' : 'Needs Analysis not finished', '6' : 'Coach not assigned', '7' : 'Coaching assignment not advanced to plan', '8' : 'Coaching plan not finished', '9' : 'Coaching plan not validated by KAM', '10' : 'Coaching plan not validated by the Head of Coaching Service', '11' : 'Coaching plan not approved', '12' : 'Coaching contract not signed', '13' : 'Coaching contract not advanced to report ', '14' : 'Coaching report not finished', '15' : 'Status Closing not initiated by KAM', '16' : 'Information check not finished', '17' : 'Coaching report not approved', '18' : 'Feedbacks not initiated'};
$('#results tr > td:nth-child(13)').each( 
  function (i, e) { 
    var n = $(e), src = n.text(), input = src.split(","), output = [], k;
    while (k = $.trim(input.pop())) {
      output.push(todo[k]);
    };
    n.text(output.join(", "));
  }
  );
</script>
    </xsl:if>
  </xsl:template>

  <xsl:template match="@Call"> for Call <xsl:value-of select="."/> and Phase <xsl:value-of select="../@Phase"/>
  </xsl:template>

  <xsl:template match="Cases[count(Case) = 0]">
    <p>Empty</p>
  </xsl:template>

  <!-- cases for a single pre-selected call -->
  <xsl:template match="Case">
    <tr data-case="{No}">
      <td><a href="{/Cases/@Base}/cases/{No}" target="_blank"><xsl:value-of select="No"/></a></td>
      <td><xsl:value-of select="Country"/></td>
      <td><xsl:value-of select="Acronym"/></td>
      <td><a href="{/Cases/@Base}/cases/{No}" target="_blank"><xsl:value-of select="PID"/></a></td>
      <td><xsl:apply-templates select="Date"/></td>
      <td><xsl:apply-templates select="KAM"/></td>
      <td><xsl:apply-templates select="SN"/></td>
      <td><xsl:apply-templates select="KN"/></td>
      <td><xsl:apply-templates select="NA"/></td>
      <td><xsl:apply-templates select="A/Coach"/></td>
      <td><xsl:apply-templates select="A/CP"/></td>
      <td><xsl:apply-templates select="A/Contract"/></td>
      <td><xsl:apply-templates select="A/Pool"/></td>
    </tr>
  </xsl:template>

  <!-- all cases w/o activity -->
  <xsl:template match="Case[../@Call = 'all']">
    <xsl:variable name="bg">
      <xsl:choose>
        <xsl:when test="position() mod 2 = 1">#EEE</xsl:when>
        <xsl:otherwise>#CCC</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <tr data-case="{No}" style="background-color:{$bg}">
      <td><a href="{/Cases/@Base}/cases/{No}" target="_blank"><xsl:value-of select="No"/></a></td>
      <td><xsl:value-of select="Country"/></td>
      <td><xsl:value-of select="PH"/></td>
      <td><xsl:value-of select="Call"/></td>
      <td><xsl:value-of select="Acronym"/></td>
      <td><a href="{/Cases/@Base}/cases/{No}" target="_blank"><xsl:value-of select="PID"/></a></td>
      <td><xsl:value-of select="Date"/></td>
      <td><xsl:value-of select="KAM"/></td>
      <td><xsl:apply-templates select="SN"/></td>
      <td><xsl:apply-templates select="KN"/></td>
      <td><xsl:value-of select="NA"/></td>
      <td><xsl:value-of select="S"/></td>
      <td><xsl:value-of select="../TBD"/></td>
      <td></td>
      <td></td>
      <td></td>
      <td></td>
      <td></td>
      <td></td>
      <td><xsl:value-of select="Km"/></td>
      <td></td>
      <td><xsl:value-of select="Pm"/></td>
    </tr>
  </xsl:template>
  
  <!-- all cases with activity -->
  <xsl:template match="Case[../@Call = 'all'][A]">
    <xsl:variable name="bg">
      <xsl:choose>
        <xsl:when test="position() mod 2 = 1">#EEE</xsl:when>
        <xsl:otherwise>#CCC</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:for-each select="A">
      <tr data-case="{../No}" style="background-color:{$bg}">
        <td><a href="{/Cases/@Base}/cases/{../No}/activities/{No}" target="_blank"><xsl:value-of select="../No"/></a></td>
        <td><xsl:value-of select="../Country"/></td>
        <td><xsl:value-of select="../PH"/></td>
        <td><xsl:value-of select="../Call"/></td>
        <td><xsl:value-of select="../Acronym"/></td>
        <td><a href="{/Cases/@Base}/cases/{../No}" target="_blank"><xsl:value-of select="../PID"/></a></td>
        <td><xsl:value-of select="../Date"/></td>
        <td><xsl:value-of select="../KAM"/></td>
        <td><xsl:apply-templates select="../SN"/></td>
        <td><xsl:apply-templates select="../KN"/></td>
        <td><xsl:value-of select="../NA"/></td>
        <td><xsl:value-of select="../S"/></td>
        <td>
          <xsl:choose>
            <xsl:when test="../TBD and TBD"><xsl:value-of select="concat(../TBD, ', ', TBD)"/></xsl:when>
            <xsl:otherwise><xsl:value-of select="TBD"/></xsl:otherwise>
          </xsl:choose>
        </td>
        <td><xsl:value-of select="Coach"/></td>
        <td><xsl:apply-templates select="CP" mode="all"/></td>
        <td><xsl:value-of select="Contract"/></td>
        <td><xsl:value-of select="Pool"/></td>
        <td><xsl:apply-templates select="CP" mode="days"/></td>
        <td><xsl:value-of select="S"/></td>
        <td><xsl:value-of select="../Km"/></td>
        <td><xsl:value-of select="Cm"/></td>
        <td><xsl:value-of select="../Pm"/></td>
      </tr>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="Date | KAM | SN | KN | NA"><xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="Date[. ='']"><button class="btn">sign</button>
  </xsl:template>

  <xsl:template match="SN[. ='']">not sent
  </xsl:template>

  <xsl:template match="KN[. ='']"></xsl:template>

  <xsl:template match="Coach"><xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="Coach[. = '']">not assigned
  </xsl:template>

  <xsl:template match="Coach[parent::A/following-sibling::A]"><xsl:value-of select="."/>,<xsl:text> </xsl:text>
  </xsl:template>

  <xsl:template match="Coach[. = ''][parent::A/following-sibling::A]">not assigned,<xsl:text> </xsl:text>
  </xsl:template>

  <xsl:template match="CP"><xsl:value-of select="@Date"/> (<xsl:value-of select="."/>H)
  </xsl:template>

  <xsl:template match="CP[parent::A/following-sibling::A]"><xsl:value-of select="@Date"/> (<xsl:value-of select="."/>H),<xsl:text> </xsl:text>
  </xsl:template>

  <xsl:template match="CP" mode="all"><xsl:value-of select="@Date"/> (<xsl:value-of select="."/>H)
  </xsl:template>

  <xsl:template match="CP" mode="days"><xsl:value-of select="format-number(. div 8,'##0')"/>
  </xsl:template>
  
  <xsl:template match="CP[. = '']" mode="days">
  </xsl:template>

  <xsl:template match="Contract"><xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="Contract[. = '']">pending
  </xsl:template>

  <xsl:template match="Contract[. != ''][parent::A/following-sibling::A]"><xsl:value-of select="."/>,<xsl:text> </xsl:text>
  </xsl:template>

  <xsl:template match="Contract[. = ''][parent::A/following-sibling::A]">pending,<xsl:text> </xsl:text>
  </xsl:template>

  <xsl:template match="Pool"><xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="Pool[. = '']">pending
  </xsl:template>

  <xsl:template match="Pool[. != ''][parent::A/following-sibling::A]"><xsl:value-of select="."/>,<xsl:text> </xsl:text>
  </xsl:template>

  <xsl:template match="Pool[. = ''][parent::A/following-sibling::A]">pending,<xsl:text> </xsl:text>
  </xsl:template>
</xsl:stylesheet>

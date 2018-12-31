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
    <site:view skin="axel">
      <site:window><title>Call <xsl:value-of select="Cases/@CallDate"/> Phase <xsl:value-of select="Cases/@Phase"/> assignment</title></site:window>
      <site:content>
        <xsl:apply-templates select="Cases | Error"/>
        <div id="c-saving">
          <span class="c-saving" loc="term.saving">Enregistrement en cours...</span>
        </div>
      </site:content>
    </site:view>
  </xsl:template>

  <xsl:template match="Error">
    <p class="text-error"><xsl:value-of select="."/></p>
  </xsl:template>

  <xsl:template match="Cases">
    <xsl:variable name="total1"><xsl:value-of select="count(Case[EEN[not(@Ref)]])"/></xsl:variable>
    <xsl:variable name="total2"><xsl:value-of select="count(Case[count(EEN[@Ref]) = 1])"/></xsl:variable>
    <xsl:variable name="total3"><xsl:value-of select="count(Case[count(EEN) > 1])"/></xsl:variable>
    <xsl:variable name="total4"><xsl:value-of select="count(Case[count(EEN) = 0])"/></xsl:variable>
    <xsl:variable name="total5"><xsl:value-of select="count(Case[Hold])"/></xsl:variable>
    <xsl:variable name="total6"><xsl:value-of select="count(Case[NoCoaching])"/></xsl:variable>

    <h1>Batch Cases Assignment</h1>

    <div class="row-fluid">
      <div class="span6">
        <table class="table table-bordered">
          <caption style="margin:20px 0 10px;text-align:left"><b>Summary</b><xsl:apply-templates select="@CallDate"/>, generated at <xsl:value-of select="substring(/Cases/@Date, 12, 5)"/> on <xsl:value-of select="substring(/Cases/@Date, 1, 10)"/></caption>
          <tr>
            <td style="width:80%">Assigned</td>
            <td><xsl:value-of select="$total1"/></td>
          </tr>
          <tr>
            <td>Can assign</td>
            <td><xsl:value-of select="$total2"/></td>
          </tr>
          <tr>
            <td>Ambiguous</td>
            <td><xsl:value-of select="$total3"/></td>
          </tr>
          <tr>
            <td>Not found</td>
            <td><xsl:value-of select="$total4"/></td>
          </tr>
          <tr>
            <td style="padding-left: 5em"><i>On hold</i></td>
            <td style="padding-left: 5em"><i><xsl:value-of select="$total5"/></i></td>
          </tr>
          <tr>
            <td style="padding-left: 5em"><i>No coaching</i></td>
            <td style="padding-left: 5em"><i><xsl:value-of select="$total6"/></i></td>
          </tr>
          <tr>
            <td>Total</td>
            <td><xsl:value-of select="$total1 + $total2 + $total3 + $total4"/></td>
          </tr>
        </table>
      </div>
      <div class="c-menu-scope span6 noprint" style="border: solid 1px lightgray">
        <div id="editor" data-template="#" style="padding:10px">
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
            Number of Projects to assign : <xt:use types="input" param="size=3;class=assign" label="Number">1</xt:use>
          </p>
          <p>
            Assign only coordinator <xt:use types="input" param="type=checkbox;name=Coordinator;value=true;checked=true" label="Coordinator"/>
          </p>  
        </div>
        <p style="text-align:center"><button class="btn" data-command="save c-inhibit" data-save-flags="silentErrors" data-target="editor" data-src="assign.xml">Assign</button></p>
      </div>
    </div>

    <fieldgroup class="noprint" styme="clear:both">
      <legend>Legend</legend>
      <dl class="noprint">
        <dt>assigned</dt>
        <dd>the Case has already been assigned and so would not be concerned by the batch</dd>
        <dt>can assign</dt>
        <dd>the Case has not been assigned and the batch could assign it to the unique EEN shown in the EEN column</dd>
        <dt>ambiguous</dt>
        <dd>the Case could not be assigned automatically since the batch found multiple EEN regions matching the nuts code information</dd>
        <dt>not found</dt>
        <dd>the Case could not be assigned automatically since the batch didn't find any EEN region matching the nuts code</dd>
      </dl>
      <p>Click on a column header to sort the table</p>
    </fieldgroup>

    <table id="results" class="table table-bordered">
      <caption style="margin:20px 0 10px;text-align:left"><b><xsl:value-of select="count(Case)"/> Case(s)</b><xsl:apply-templates select="@Call"/>, generated by <xsl:value-of select="@User"/> at <xsl:value-of select="substring(/Cases/@Date, 12, 5)"/> on <xsl:value-of select="substring(/Cases/@Date, 1, 10)"/></caption>
      <thead>
        <tr>
          <th>Project Id</th>
          <th>Beneficiary PIC</th>
          <th>Acronym</th>
          <th>State</th>
          <th>EEN</th>
        </tr>
      </thead>
      <tbody>
        <xsl:apply-templates select="Case"/>
      </tbody>
    </table>
  </xsl:template>

  <xsl:template match="@Call"> for Call <xsl:value-of select="."/> and Phase <xsl:value-of select="../@Phase"/>
  </xsl:template>

  <xsl:template match="Cases[count(Case) = 0]">
    <p>Empty</p>
  </xsl:template>

  <xsl:template match="Case">
    <tr>
      <td>
        <a target="_blank">
          <xsl:attribute name="href">
            <xsl:value-of select="/Cases/@Base"/>/projects/<xsl:value-of select="Id"/><xsl:if test="@CaseNo">/cases/<xsl:value-of select="@CaseNo"/></xsl:if>
          </xsl:attribute>
        <xsl:value-of select="Id"/></a></td>
      <td><xsl:value-of select="PIC"/></td>
      <td><xsl:value-of select="Acronym"/></td>
      <td><xsl:apply-templates select="." mode="state"/></td>
      <td><xsl:apply-templates select="EEN | error"/></td>
    </tr>
  </xsl:template>

  <xsl:template match="Case" mode="state">assigned
  </xsl:template>

  <xsl:template match="Case[count(EEN) = 0]" mode="state">not found
  </xsl:template>

  <xsl:template match="Case[count(EEN) > 1]" mode="state">ambiguous
  </xsl:template>

  <xsl:template match="Case[count(EEN[@Ref]) = 1]" mode="state">can assign
  </xsl:template>

  <xsl:template match="Case[Hold]" mode="state">on hold
  </xsl:template>

  <xsl:template match="Case[NoCoaching]" mode="state">no coaching
  </xsl:template>

  <xsl:template match="EEN"><xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="EEN[following-sibling::EEN]"><xsl:value-of select="."/>,<xsl:text> </xsl:text>
  </xsl:template>

  <xsl:template match="EEN[@Test = 'ok']"><span style="color:green"><xsl:value-of select="."/></span><xsl:text> </xsl:text>
  </xsl:template>  

  <xsl:template match="EEN[@Test = 'nok']"><span style="color:red"><xsl:value-of select="."/></span><xsl:text> </xsl:text>
  </xsl:template>  
</xsl:stylesheet>

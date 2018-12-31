<?xml version="1.0" encoding="UTF-8"?>

<!-- CCTRACKER - EIC Case Tracker Application

     Author: Frédéric Dumonceaux <fred.dumonceaux@gmail.com>

     Cases exportation facility

     April 2016 - European Union Public Licence EUPL
  -->

<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site"
  xmlns:xt="http://ns.inria.org/xtiger"
  xmlns="http://www.w3.org/1999/xhtml">

  <!-- TODO: add <site:title> for window title when skin handles pure text() -->
  <xsl:template match="/">
    <site:view>
      <site:title><title><xsl:value-of select="Annex/@Coach"/> Business coaching plan</title></site:title>
      <site:content>
        <h1>Coaching plan summary</h1>
        <xsl:apply-templates select="Annex"/>
      </site:content>
    </site:view>
  </xsl:template>

  <xsl:template match="Annex">
    <table class="table table-bordered no-sort">
      <caption style="margin:20px 0 10px;text-align:left">
          Generated by <xsl:value-of select="@User"/> at <xsl:value-of select="substring(@Date, 12, 5)"/> on <xsl:value-of select="substring(@Date, 1, 10)"/>
      </caption>
      <tbody>
        <tr><td style="font-weight:bold;background-color:#9ec0d9;width:150px;">Name of the company</td><td><xsl:value-of select="Name"/></td></tr>
        <tr><td style="font-weight:bold;background-color:#9ec0d9;width:150px;">Acronym of the grant agreement</td><td><xsl:value-of select="Acronym"/></td></tr>
        <tr><td style="font-weight:bold;background-color:#9ec0d9;width:150px;">Number of the grant agreement</td><td><xsl:value-of select="ProjectId"/></td></tr>
        <tr><td style="font-weight:bold;background-color:#9ec0d9;width:150px;">Name of the coach</td><td><xsl:value-of select="@Coach"/></td></tr>
      </tbody>
    </table>
    <table id="results" class="table table-bordered no-sort">
      <thead>
        <th>Objectives</th>
      </thead>
      <tbody>
        <tr><td><xsl:apply-templates select="Objectives/Text"/></td></tr>
      </tbody>
    </table>
    <table id="results" class="table table-bordered no-sort">
      <thead>
        <th style="text-align:center;">Activities</th>
        <th style="text-align:center;">Number of hours</th>
      </thead>
      <tbody>
         <xsl:apply-templates select="Tasks/Task"/>
        <tr><td style="text-align:right;">Total</td><td><xsl:value-of select="sum(Tasks/Task/NbOfHours[ . != ''])" /></td></tr>
      </tbody>
    </table>
    <div class="modal-footer c-menu-scope">
      <button onclick="window.open('annex.pdf','_newtab')" style="float:left" class="btn btn-primary">Generate PDF</button>
      <button onclick="window.open('annex.pdf?terms=1','_newtab')" style="margin-left:10px;float:left" class="btn btn-primary">Generate PDF (+ Terms of Reference)</button>
    </div>
  </xsl:template>
  
  <xsl:template match="Text">
    <p><xsl:value-of select="."/></p>
  </xsl:template>
  <xsl:template match="Task">
    <tr><td><xsl:value-of select="./Description"/></td>
    <td><xsl:value-of select="./NbOfHours"/></td></tr>
  </xsl:template>
  
  
</xsl:stylesheet>
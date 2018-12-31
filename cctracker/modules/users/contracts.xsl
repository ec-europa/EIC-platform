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
    <site:view>
      <site:title><title><xsl:value-of select="Contracts/@Coach"/> contracts</title></site:title>
      <site:content>
        <h1>Contracts</h1>
        <xsl:apply-templates select="Contracts"/>
      </site:content>
    </site:view>
  </xsl:template>

  <xsl:template match="Contracts">
    <div id="results-export">Export <a download="{@Coach}.xls" href="#" class="export">excel</a> <a download="{@Coach}.csv" href="#" class="export">csv</a></div>
    <table id="results" class="table table-bordered no-sort">
      <caption style="margin:20px 0 10px;text-align:left"><xsl:value-of select="count(Contract[Nature = 'Contract'])"/> Contract(s) and <xsl:value-of select="count(Contract[Nature = 'Amendment'])"/> Amendment(s) for <b><xsl:value-of select="@Coach"/></b>, generated by <xsl:value-of select="@User"/> at <xsl:value-of select="substring(@Date, 12, 5)"/> on <xsl:value-of select="substring(@Date, 1, 10)"/></caption>
      <thead>
        <tr>
          <th>Pool</th>
          <th>Nature</th>
          <th># of working days</th>
          <th>Date</th>
          <th>SME Beneficiary</th>
          <th>Acronym</th>
          <th>Case ID</th>
          <th>Project ID</th>
          <th>Phase</th>
        </tr>
      </thead>
      <tbody>
        <xsl:apply-templates select="Contract">
          <xsl:sort select="Date"/>
        </xsl:apply-templates>
        <tr>
          <td></td>
          <td><i>Total working days</i></td>
          <td><xsl:value-of select="sum(Contract/TotalNbOfHours) div 8"/></td>
          <td></td>
          <td></td>
          <td></td>
          <td></td>
          <td></td>
          <td></td>
        </tr>
      </tbody>
    </table>
  </xsl:template>

  <xsl:template match="Contracts[count(Contract) = 0]">
    <p>No contract yet for <xsl:value-of select="@Coach"/></p>
  </xsl:template>

  <xsl:template match="Contract">
    <tr>
      <td><xsl:value-of select="PoolNumber"/></td>
      <td><xsl:value-of select="Nature"/></td>
      <td><xsl:value-of select="TotalNbOfHours div 8"/></td>
      <td><xsl:value-of select="Date"/></td>
      <td><xsl:value-of select="SME"/></td>
      <td><xsl:value-of select="Acronym"/></td>
      <td><xsl:value-of select="@CaseNo"/></td>
      <td><xsl:value-of select="@ProjectId"/></td>
      <td><xsl:value-of select="PhaseRef"/></td>
    </tr>
  </xsl:template>
</xsl:stylesheet>

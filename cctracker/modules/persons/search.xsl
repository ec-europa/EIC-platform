<?xml version="1.0" encoding="UTF-8"?>
<!-- CCTRACKER - EIC Case Tracker Application

     Author: Stéphane Sire <s.sire@opppidoc.fr>

     XSL templates to generate Person search scaffold and the initial search results table

     January 2015 - European Union Public Licence EUPL
  -->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site" xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>

  <xsl:param name="xslt.base-url">/</xsl:param>

  <!-- =========== -->
  <!-- EXTENSIONS  -->
  <!-- =========== -->
  <xsl:include href="../../lib/commons.xsl"/>
  <xsl:include href="../../lib/widgets.xsl"/>
  <xsl:include href="../../lib/search.xsl"/>
  <xsl:include href="../match/suggest.xsl"/>
  <xsl:include href="person.xsl"/>

  <!-- SubTitle under Template title -->
  <xsl:template match="@sub-loc">
    <p class="text-info" style="margin-top:0;font-size:16px;text-align:center" loc="{.}"><xsl:value-of select="."/></p>
  </xsl:template>

  <!-- Search results set in a fragment (Ajax) -->
  <xsl:template match="/Search">
    <div id="results">
      <xsl:apply-templates select="/Search/NoRequest | /Search/Results/Empty | /Search/Results/Persons | /Search/Results/Coaches "/>
    </div>
  </xsl:template>

  <!-- Search initial User Interface  -->
  <xsl:template match="/Search[@Initial='true']" priority="1">
    <site:view skin="{@skin}">
      <site:window><title loc="{Formular/Template/@loc}">Title</title></site:window>
      <site:title>
        <h1 loc="{Formular/Template/@loc}">Title</h1>
        <xsl:apply-templates select="Formular/Template/@sub-loc"/>
      </site:title>
      <site:content>
        <xsl:apply-templates select="Formular"/>
        <div class="row">
          <div class="span12">
            <p id="c-busy" style="display: none; color: #999;margin-left:380px;height:32px">
              <span loc="term.loading" style="margin-left: 50px;vertical-align:middle">Recherche en cours...</span>
            </p>
            <div id="results">
              <xsl:apply-templates select="/Search/*[local-name(.) != 'Formular' and local-name(.) != 'Modals' and local-name(.) != 'Overlay']"/>
            </div>
          </div>
        </div>
        <xsl:apply-templates select="/Search/Modals/Modal"/>
      </site:content>
      <xsl:apply-templates select="/Search/Overlay"/>
    </site:view>
  </xsl:template>

  <xsl:template match="Persons[not(Person)]">
    <h2 loc="app.title.noResults">Pas de résultats</h2>
    <p loc="app.message.noResults">Il n'y a pas de résultats pour les critères sélectionnés.</p>
  </xsl:template>

  <!-- Generic persons search page -->
  <xsl:template match="Persons">
    <h2><span loc="person.search.result.message1">Résultats</span> – <xsl:value-of select="count(Person/Id)"/><xsl:text> </xsl:text><span loc="person.search.result.message2">personne(s)</span></h2>

    <table class="table table-bordered">
      <thead>
        <tr>
          <th loc="term.name">Nom</th>
          <th loc="term.country" style="min-width:7em">Pays</th>
          <th loc="term.email">Email</th>
          <th loc="term.mobile" class="mobile">Mobile</th>
          <th loc="term.phone" class="phone">Téléphone</th>
          <th loc="term.enterprise">Entreprise</th>
        </tr>
      </thead>
      <tbody localized="1">
        <xsl:apply-templates select="Person">
          <xsl:sort select="Name/LastName" order="ascending"/>
        </xsl:apply-templates>
      </tbody>
    </table>
  </xsl:template>

  <!-- Specific coaches search page -->
  <xsl:template match="Coaches">
    <h2><span loc="person.search.result.message1">Résultats</span> – <xsl:value-of select="count(.//Coach)"/><xsl:text> </xsl:text><span>coach(es)</span></h2>
    <table class="table table-bordered">
      <thead>
        <tr>
          <th loc="term.service">Service</th>
          <th loc="term.country">Country</th>
          <th loc="term.coach">Coach</th>
        </tr>
      </thead>
      <tbody localized="1">
        <xsl:apply-templates select="Service"/>
      </tbody>
    </table>
  </xsl:template>

  <!-- TODO: localize  -->
  <xsl:template match="Coaches[count(.//Coach) = 0]">
    <h2 loc="app.title.noResults">Pas de résultats</h2>
    <p style="margin-bottom:30px">There is currently no coach corresponding to the criteria</p>
    <xsl:if test="not(parent::Results/@Services = 'hideIfEmpty')">
      <table class="table table-bordered">
        <thead>
          <tr>
            <th loc="term.service">Service</th>
            <th loc="term.country">Country</th>
            <th loc="term.coach">Coach</th>
          </tr>
        </thead>
        <tbody localized="1">
          <xsl:apply-templates select="Service"/>
        </tbody>
      </table>
    </xsl:if>
  </xsl:template>

  <xsl:template match="*|@*|text()">
    <xsl:copy>
      <xsl:apply-templates select="*|@*|text()"/>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>

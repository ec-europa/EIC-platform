<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site" xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>

  <xsl:param name="xslt.base-url">/</xsl:param>

  <xsl:include href="../../lib/commons.xsl"/>
  <xsl:include href="../../lib/widgets.xsl"/>
  <xsl:include href="../../lib/search.xsl"/>
  <xsl:include href="region.xsl"/>
  
  <xsl:template match="/Search">
    <div id="results">
      <xsl:apply-templates select="/Search/NoRequest | /Search/Results/Empty | /Search/Results/RegionalEntities"/>
    </div>
  </xsl:template>

  <!-- FIXME: rename skin to "search regions" to factorize with enterprises, persons, stage (?) -->
  <xsl:template match="/Search[@Initial='true']" priority="1">
    <site:view skin="persons">
      <site:window><title loc="form.title.regions.search">Title</title></site:window>
      <site:title>
        <h1 loc="form.title.regions.search">Search of regions</h1>
      </site:title>
      <site:content>
        <xsl:apply-templates select="Formular"/>
        <div class="row">
          <div class="span12">
            <p id="c-busy" style="display: none; color: #999;margin-left:380px;height:32px">
              <span loc="term.loading" style="margin-left: 50px;vertical-align:middle">Search in progress...</span>
            </p>
            <div id="results">
              <xsl:apply-templates select="/Search/NoRequest | /Search/Results/Empty | /Search/Results/RegionalEntities"/>
            </div>
          </div>
        </div>
        <xsl:apply-templates select="/Search/Modals/Modal"/>
      </site:content>
    </site:view>
  </xsl:template>

  <xsl:template match="RegionalEntities[not(RegionalEntity)]">
    <h2 loc="app.title.noResults">No results</h2>
    <p loc="app.message.noResults">There are no results for those criterias</p>
  </xsl:template>

  <xsl:template match="RegionalEntities">
    <h2><span loc="person.search.result.message1">Results</span> – <xsl:value-of select="count(RegionalEntity/Id)"/><xsl:text> </xsl:text><span>regional entitie(s)</span></h2>

    <table class="table table-bordered">
      <thead>
        <tr>
          <th>EEN Entity</th>
          <th>Country</th>
          <th>EEN KAM Coordinator</th>
          <th>KAM</th>
        </tr>
      </thead>
      <tbody localized="1">
        <xsl:apply-templates select="RegionalEntity"/>
      </tbody>
    </table>
  </xsl:template>

</xsl:stylesheet>

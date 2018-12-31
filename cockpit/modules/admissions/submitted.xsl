<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site" xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>

  <xsl:param name="xslt.base-url">/</xsl:param>

  <xsl:include href="../../lib/commons.xsl"/>
  <xsl:include href="../../lib/widgets.xsl"/>
  <xsl:include href="../../app/custom.xsl"/>
  

  <!-- FIXME: factorize with Editor, Accordion -->
  <xsl:template match="Document">
    <div class="row-fluid c-documents">
      <div id="c-editor-{@Id}" class="c-autofill-border"
        data-template="{Template}"
        data-src="{Resource}"
        >
        <noscript loc="app.message.js">Activate Javascript</noscript>
        <p loc="app.message.loading">Loading formular</p>
      </div>
    </div>
  </xsl:template>


  <xsl:template match="*|@*|text()">
    <xsl:copy>
      <xsl:apply-templates select="*|@*|text()"/>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
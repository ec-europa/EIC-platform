<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site" xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>

  <xsl:param name="xslt.base-url">/</xsl:param>

  <xsl:include href="../../lib/commons.xsl"/>
  <xsl:include href="../../lib/widgets.xsl"/>
  <xsl:include href="../../lib/accordion.xsl"/>
  <xsl:include href="../../app/custom.xsl"/>

  <!-- TODO: move to commons.xsl ? -->
  <xsl:template match="error" priority="1">
    <h2>Oops !</h2>
  </xsl:template>

</xsl:stylesheet>
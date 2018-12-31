<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site" xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>

  <xsl:param name="xslt.base-url">/</xsl:param>

  <xsl:include href="../../lib/commons.xsl"/>
  <xsl:include href="../../lib/widgets.xsl"/>
  <xsl:include href="../../app/custom.xsl"/>
  
  <!-- Quick and dirty hack to duplicate Submit Answers menu -->
  <xsl:template match="LoginMenuOverlay">
    <xsl:variable name="target"><xsl:value-of select="@Target"/></xsl:variable>
    <site:login>
      <button class="btn btn-primary"
        data-command="save c-inhibit"
        data-save-flags="silentErrors"
        data-target="c-editor-{$target}"
        data-replace-type="event"
        data-src="{ /Page//Editor[Id = $target]/Controller }"
        >Submit Answers</button>
    </site:login>
  </xsl:template>

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

  <!-- FIXME: refactor as Document, factorize with Accordion -->
  <xsl:template match="Editor">
    <div class="row-fluid c-documents">
      <div id="c-editor-{@Id}-errors" class="alert alert-error af-validation"></div>
      <div id="c-editor-{@Id}" class="c-autofill-border"
        data-template="{Template}"
        data-validation-output="c-editor-{@Id}-errors" 
        data-validation-label="label"
        >
        <xsl:if test="@data-autoscroll-shift">
          <xsl:attribute name="data-command">autoscroll</xsl:attribute>
          <xsl:copy-of select="@data-autoscroll-shift"/>
        </xsl:if>
        <noscript loc="app.message.js">Activate Javascript</noscript>
        <p loc="app.message.loading">Loading formular</p>
      </div>
    </div>
    <div class="row-fluid" style="margin: 20px 0 30px">
      <div id="c-editor-{@Id}-menu" class="c-menu-scope span12 offset9">
        <button class="btn btn-primary"
          data-command="save c-inhibit"
          data-save-flags="silentErrors"
          data-target="c-editor-{@Id}"
          data-replace-type="event"
          data-src="{ Controller }"
          >Submit Answers</button>
      </div>
    </div>
  </xsl:template>

  <xsl:template match="*|@*|text()">
    <xsl:copy>
      <xsl:apply-templates select="*|@*|text()"/>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
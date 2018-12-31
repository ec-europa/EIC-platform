<?xml version="1.0" encoding="UTF-8"?>
<!-- Oppidoc Supergrid application

     Author: Stéphane Sire <s.sire@opppidoc.fr>

     Table driven forms extension

     September 2015 - European Union Public Licence EUPL
  -->

<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xt="http://ns.inria.org/xtiger"
                xmlns:site="http://oppidoc.com/oppidum/site"
                xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output encoding="UTF-8" indent="yes" method="xml" />

  <xsl:template match="ProductTable">
    <xsl:variable name="component-type"><xsl:value-of select="../@name"/></xsl:variable>
    <xsl:variable name="use-tag"><xsl:value-of select="ancestor-or-self::node()[last()]//Use[contains($component-type,@TypeName)]/@Tag"/></xsl:variable>
    <xsl:variable name="modal"><xsl:value-of select="Combine/Selector[1]/@Modal"/></xsl:variable>
    <xsl:variable name="src1"><xsl:value-of select="concat('xmldb:exist:///db/sites/ccmatch/global-information/', Combine/Selector[1]/@Document)"/></xsl:variable>
    <xsl:variable name="src2"><xsl:value-of select="concat('xmldb:exist:///db/sites/ccmatch/global-information/', Combine/Selector[2]/@Document)"/></xsl:variable>
    <xsl:variable name="selector1"><xsl:value-of select="Combine/Selector[1]/text()"/></xsl:variable>
    <xsl:variable name="selector2"><xsl:value-of select="Combine/Selector[2]/text()"/></xsl:variable>
    <xsl:variable name="w"><xsl:value-of select="Combine/Selector[2]/@Width"/></xsl:variable>
    <xsl:variable name="levels">
      <xsl:choose>
        <!-- Flat selector-->
        <xsl:when test="document($src1)//Description[@Lang = 'en']/Selector[@Name = $selector1]/Option">1</xsl:when>
        <!-- Hierarchical selector-->
        <xsl:when test="document($src1)//Description[@Lang = 'en']/Selector[@Name = $selector1]/Group">2</xsl:when>
      </xsl:choose>
    </xsl:variable>
    <xsl:apply-templates select="." mode="validation"/>
    <table>
      <xsl:choose>
        <xsl:when test="Combine/Selector[1]/@CardMax">
          <xsl:attribute name="class">table table-bordered control-group</xsl:attribute>
          <xsl:attribute name="data-binding">cardinality</xsl:attribute>
          <xsl:attribute name="data-variable"><xsl:value-of select="$selector1"/></xsl:attribute>
          <xsl:attribute name="data-error-scope">th.control-group</xsl:attribute>
          <xsl:attribute name="data-cardinality-value"><xsl:value-of select="Combine/Selector[1]/@CardOnValue"/></xsl:attribute>
          <xsl:attribute name="data-cardinality-max"><xsl:value-of select="Combine/Selector[1]/@CardMax"/></xsl:attribute>
        </xsl:when>
        <xsl:otherwise>
          <xsl:attribute name="class">table table-bordered</xsl:attribute>
        </xsl:otherwise>
      </xsl:choose>
      <tr>
        <th colspan="{$levels}" style="width:{Title/@Width}"><xsl:value-of select="Title"/><xsl:apply-templates select="." mode="hint"/>
</th>
        <xsl:apply-templates select="document($src2)//Description[@Lang = 'en']/Selector[@Name = $selector2]/Option" mode="tabular2">
          <xsl:with-param name="w"><xsl:value-of select="$w"/></xsl:with-param>
          <xsl:with-param name="card-column"><xsl:value-of select="Combine/Selector[1]/@CardOnValue"/></xsl:with-param>
          <xsl:with-param name="key"><xsl:value-of select="$selector1"/></xsl:with-param>
        </xsl:apply-templates>
      </tr>
      <xsl:choose>
        <!-- Flat selector-->
        <xsl:when test="$levels = '1'">
          <xsl:apply-templates select="document($src1)//Description[@Lang = 'en']/Selector[@Name = $selector1]/Option" mode="tabular1">
            <xsl:with-param name="src2"><xsl:value-of select="$src2"/></xsl:with-param>
            <xsl:with-param name="use-tag"><xsl:value-of select="$use-tag"/></xsl:with-param>
            <xsl:with-param name="selector1"><xsl:value-of select="$selector1"/></xsl:with-param>
            <xsl:with-param name="selector2"><xsl:value-of select="$selector2"/></xsl:with-param>
            <xsl:with-param name="modal"><xsl:value-of select="$modal"/></xsl:with-param>
            <xsl:with-param name="modal-tpl"><xsl:value-of select="ancestor-or-self::node()[last()]//Modal[@Id = $modal]/@Template"/></xsl:with-param>
            <xsl:with-param name="tag"><xsl:value-of select="Combine/Selector[1]/@Prefix"/></xsl:with-param>
            <xsl:with-param name="suffixes"><xsl:value-of select="Combine/Selector[1]/@ConfirmIndex"/></xsl:with-param>
            <xsl:with-param name="value"><xsl:value-of select="Combine/Selector[1]/@ConfirmValue"/></xsl:with-param>
            <xsl:with-param name="card-column"><xsl:value-of select="Combine/Selector[1]/@CardOnValue"/></xsl:with-param>
          </xsl:apply-templates>
        </xsl:when>
        <!-- Hierarchical selector-->
        <xsl:when test="$levels = '2'">
          <xsl:apply-templates select="document($src1)//Description[@Lang = 'en']/Selector[@Name = $selector1]/Group" mode="tabular1">
            <xsl:with-param name="src2"><xsl:value-of select="$src2"/></xsl:with-param>
            <xsl:with-param name="selector1"><xsl:value-of select="$selector1"/></xsl:with-param>
            <xsl:with-param name="selector2"><xsl:value-of select="$selector2"/></xsl:with-param>
            <xsl:with-param name="tag"><xsl:value-of select="Combine/Selector[1]/@Prefix"/></xsl:with-param>
            <xsl:with-param name="card-column"><xsl:value-of select="Combine/Selector[1]/@CardOnValue"/></xsl:with-param>
          </xsl:apply-templates>
        </xsl:when>
      </xsl:choose>
    </table>
  </xsl:template>

  <xsl:template match="ProductTable[Combine/Selector/@CardMax]" mode="validation">
    <p class="af-label" style="display:none"><xsl:value-of select="Title"/> because you cannot be a specialist in more than <xsl:value-of select="Combine/Selector/@CardMax"/> fields</p>
  </xsl:template>

  <xsl:template match="ProductTable" mode="validation">
  </xsl:template>
  
  <xsl:template match="ProductTable[Combine/Selector/@CardMax]" mode="hint">
    <span class="sg-hint reverse" rel="tooltip" data-placement="top" title="{concat('You can set yourself as a specialist in a maximum of ', concat(Combine/Selector/@CardMax, ' fields'))}">?</span>
  </xsl:template>

  <xsl:template match="ProductTable" mode="hint">
  </xsl:template>

  <!-- Second dimension headers  -->
  <xsl:template match="Option" mode="tabular2">
    <xsl:param name="w"></xsl:param>
    <xsl:param name="card-column"></xsl:param>
    <xsl:param name="key"></xsl:param>
    <th class="sg-radio" style="width:{$w}">
      <xsl:value-of select="Name"/>
      <xsl:choose>
        <xsl:when test="Id/text() = $card-column">
          <p class="cardinality-counter" data-cardinality-error="{$key}">left to mark</p>
        </xsl:when>
      </xsl:choose>
    </th>
  </xsl:template>

  <!-- Flat first dimension rows -->
  <xsl:template match="Option" mode="tabular1">
    <xsl:param name="src2"></xsl:param>
    <xsl:param name="modal"></xsl:param>
    <xsl:param name="modal-tpl"></xsl:param>
    <xsl:param name="use-tag"></xsl:param>
    <xsl:param name="selector1"></xsl:param>
    <xsl:param name="selector2"></xsl:param>
    <xsl:param name="tag"></xsl:param>
    <xsl:param name="suffixes"></xsl:param>
    <xsl:param name="value"></xsl:param>
    <xsl:param name="card-column"></xsl:param>
    <tr>
      <xsl:choose>
        <xsl:when test="contains($suffixes,Id/text())">
          <xsl:attribute name="class">control-group</xsl:attribute>
          <xsl:attribute name="data-binding">confirm</xsl:attribute>
          <xsl:attribute name="data-variable"><xsl:value-of select="$use-tag"/></xsl:attribute>
          <xsl:attribute name="data-confirm-modal"><xsl:value-of select="$modal"/>-modal</xsl:attribute>
          <xsl:attribute name="data-confirm-modal-id"><xsl:value-of select="$modal"/></xsl:attribute>
          <xsl:attribute name="data-with-template"><xsl:value-of select="$modal-tpl"/></xsl:attribute>
          <xsl:attribute name="data-confirm-value"><xsl:value-of select="$value"/></xsl:attribute>
          <xsl:attribute name="data-error-scope">tr.control-group</xsl:attribute>
        </xsl:when>
      </xsl:choose>
      <td><xsl:value-of select="Name"/></td>
      <xsl:apply-templates select="document($src2)//Description[@Lang = 'en']/Selector[@Name = $selector2]/Option" mode="tabular3">
        <xsl:with-param name="curId"><xsl:value-of select="Id/text()"/></xsl:with-param>
        <xsl:with-param name="tag"><xsl:value-of select="$tag"/></xsl:with-param>
        <xsl:with-param name="card-col"><xsl:value-of select="$card-column"/></xsl:with-param>
        <xsl:with-param name="selector1"><xsl:value-of select="$selector1"/></xsl:with-param>
      </xsl:apply-templates>
    </tr>
  </xsl:template>

  <!-- Second dimension columns  -->
  <xsl:template match="Option" mode="tabular3">
    <xsl:param name="curId"></xsl:param>
    <xsl:param name="card-col"></xsl:param>
    <xsl:param name="tag"></xsl:param>
    <xsl:param name="selector1"></xsl:param>
      <td class="sg-radio">
        <xsl:choose>
          <xsl:when test="Id/text() = $card-col">
            <xsl:attribute name="data-cardinality-radio"><xsl:value-of select="$selector1"/></xsl:attribute>
          </xsl:when>
        </xsl:choose>
           <xt:use types="input" label="{$tag}_{$curId}" param="filter=event;type=radio;cardinality=3;name=expertise;value={Id};"/>
        <!--</site:field>-->
      </td>
    </xsl:template>

  <!-- Second dimension columns  -->
  <xsl:template match="Option[1]" mode="tabular3">
    <xsl:param name="curId"></xsl:param>
    <xsl:param name="tag"></xsl:param>
    <td class="sg-radio"><xt:use types="input" label="{$tag}_{$curId}" param="filter=event;type=radio;cardinality=3;name=expertise;value={Id};checked={Id};noxml=true"/></td>
  </xsl:template>

  <!-- Hierarchical first dimension rows  -->
  <xsl:template match="Group" mode="tabular1">
    <xsl:param name="src2"></xsl:param>
    <xsl:param name="selector1"></xsl:param>
    <xsl:param name="selector2"></xsl:param>
    <xsl:param name="tag"></xsl:param>
    <xsl:param name="card-column"></xsl:param>
    <tr>
      <td rowspan="{count(Selector/Option)}"><xsl:value-of select="Name"/></td>
      <td><xsl:value-of select="Selector/Option[1]/Name"/></td>
      <xsl:apply-templates select="document($src2)//Description[@Lang = 'en']/Selector[@Name = $selector2]/Option" mode="tabular3">
        <xsl:with-param name="curId"><xsl:value-of select="concat(Code, concat('_', Selector/Option[1]/Code))"/></xsl:with-param>
        <xsl:with-param name="tag"><xsl:value-of select="$tag"/></xsl:with-param>
        <xsl:with-param name="card-col"><xsl:value-of select="$card-column"/></xsl:with-param>
        <xsl:with-param name="selector1"><xsl:value-of select="$selector1"/></xsl:with-param>
      </xsl:apply-templates>
    </tr>
    <xsl:apply-templates select="Selector/Option[position() > 1]" mode="tabular1-iter">
      <xsl:with-param name="src2"><xsl:value-of select="$src2"/></xsl:with-param>
      <xsl:with-param name="selector1"><xsl:value-of select="$selector1"/></xsl:with-param>
      <xsl:with-param name="selector2"><xsl:value-of select="$selector2"/></xsl:with-param>
      <xsl:with-param name="curId"><xsl:value-of select="Code"/></xsl:with-param>
      <xsl:with-param name="tag"><xsl:value-of select="$tag"/></xsl:with-param>
      <xsl:with-param name="card-col"><xsl:value-of select="$card-column"/></xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>

  <!-- Hierarchical first dimension nested rows  -->
  <xsl:template match="Option" mode="tabular1-iter">
    <xsl:param name="src2"></xsl:param>
    <xsl:param name="selector1"></xsl:param>
    <xsl:param name="selector2"></xsl:param>
    <xsl:param name="curId"></xsl:param>
    <xsl:param name="tag"></xsl:param>
    <xsl:param name="card-col"></xsl:param>
    <tr>
      <td><xsl:value-of select="Name"/></td>
      <xsl:apply-templates select="document($src2)//Description[@Lang = 'en']/Selector[@Name = $selector2]/Option" mode="tabular3">
        <xsl:with-param name="curId"><xsl:value-of select="concat($curId, concat('_', Code))"/></xsl:with-param>
        <xsl:with-param name="tag"><xsl:value-of select="$tag"/></xsl:with-param>
        <xsl:with-param name="card-col"><xsl:value-of select="$card-col"/></xsl:with-param>
        <xsl:with-param name="selector1"><xsl:value-of select="$selector1"/></xsl:with-param>
      </xsl:apply-templates>
    </tr>
  </xsl:template>

</xsl:stylesheet>

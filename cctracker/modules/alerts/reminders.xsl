<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site"
  xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>

  <xsl:param name="xslt.base-url">/</xsl:param>

  <xsl:template match="/error">
    <site:view>
      <site:title><title>Case Tracker Alerts</title></site:title>
    </site:view>
  </xsl:template>

  <xsl:template match="/Reminders">
    <site:view>
      <site:title><title>Case Tracker reminders report</title></site:title>
      <site:content>
        <h1>Case Tracker latest reminders</h1>
        <xsl:apply-templates select="Digest"/>
      </site:content>
    </site:view>
  </xsl:template>

  <xsl:template match="Digest">
    <h2>Reminders of <xsl:value-of select="substring(@Timestamp, 1, 10)"/> (recorded at <xsl:value-of select="substring(@Timestamp, 12, 5)"/>)</h2>
    <xsl:apply-templates select="@Success | @Warn"/>
    <xsl:apply-templates select="." mode="table"/>
  </xsl:template>

  <xsl:template match="Digest[starts-with(@Timestamp, /Reminders/@Today)]">
    <h2>Today's <xsl:value-of select="count(Reminder)"/> reminders and <xsl:value-of select="count(AutoAdvance)"/> status changes (recorded at <xsl:value-of select="substring(@Timestamp, 12, 5)"/>)</h2>
    <xsl:apply-templates select="@Success | @Warn"/>
    <xsl:apply-templates select="." mode="table"/>
  </xsl:template>

  <xsl:template match="Digest[starts-with(@Timestamp, /Reminders/@Yesterday)]">
    <h2>Yesterday's reminders (recorded at <xsl:value-of select="substring(@Timestamp, 12, 5)"/>)</h2>
    <xsl:apply-templates select="@Success | @Warn"/>
    <xsl:apply-templates select="." mode="table"/>
  </xsl:template>

  <xsl:template match="Digest" mode="table">
    <table class="table table-bordered">
      <thead>
        <tr>
          <th style="width:350px">Reminder action</th>
          <th>To (<i>only in debug mode</i>)</th>
          <th>Elapsed</th>
          <th>Time</th>
          <th>Acronym</th>
          <th>Case</th>
          <th>Activity</th>
          <th style="width:200px">Result</th>
        </tr>
      </thead>
      <tbody>
        <xsl:apply-templates select="Reminder | AutoAdvance"/>
      </tbody>
    </table>
  </xsl:template>

  <xsl:template match="@Success">
    <p class="text-info"><xsl:value-of select="."/></p>
  </xsl:template>

  <xsl:template match="@Warn">
    <p class="text-error">WARN: <xsl:value-of select="."/></p>
  </xsl:template>

  <xsl:template match="Reminder">
      <tr>
        <td><xsl:apply-templates select="Template"/></td>
        <td><xsl:apply-templates select="To"/></td>
        <td><xsl:value-of select="@Elapsed"/></td>
        <td><xsl:value-of select="@Time"/></td>
        <td><xsl:apply-templates select="Acronym"/></td>
        <td><xsl:apply-templates select="@CaseNo"/></td>
        <td><xsl:apply-templates select="@ActivityNo"/></td>
        <td><xsl:apply-templates select="@Status"/></td>
      </tr>
  </xsl:template>
  
  <!-- FIXME: actually optional DEPRECATED e-mail Template not reported (!)
    -->
  <xsl:template match="AutoAdvance">
      <tr>
        <td><xsl:apply-templates select="Id"/></td>
        <td></td>
        <td><xsl:value-of select="@Elapsed"/></td>
        <td><xsl:value-of select="@Time"/></td>
        <td><xsl:apply-templates select="Acronym"/></td>
        <td><xsl:apply-templates select="@CaseNo"/></td>
        <td><xsl:apply-templates select="@ActivityNo"/></td>
        <td><xsl:apply-templates select="@WorkflowStatus"/></td>
      </tr>
  </xsl:template>

  <xsl:template match="@CaseNo">
    <a target="_blank" href="projects/{../@PID}/cases/{ . }"><xsl:value-of select="."/></a>
  </xsl:template>

  <xsl:template match="@CaseNo[../@ActivityNo]"><xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="Acronym"><xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="@ActivityNo"><a target="_blank" href="projects/{../@PID}/cases/{ ../@CaseNo }/activities/{ . }"><xsl:value-of select="."/></a>
  </xsl:template>
  
  <xsl:template match="@Status"><xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="@Status[. = 'cancel']">cancelled
  </xsl:template>

  <xsl:template match="@Status[. = 'off']">off (not sent, not archived)
  </xsl:template>

  <xsl:template match="@Status[. = 'double']">already sent, already archived
  </xsl:template>

  <xsl:template match="@Status[. = 'off+double']">off (already sent, already archived)
  </xsl:template>
  
  <xsl:template match="@Status[. = 'discard']">discarded, already done
  </xsl:template>

  <xsl:template match="@Status[. = 'off+discard']">off (would discard, done)
  </xsl:template>

  <xsl:template match="@Status[. = 'done']">sent, archived
  </xsl:template>

  <xsl:template match="@Status[. = 'sent']">sent, could not be archived
  </xsl:template>

  <xsl:template match="@Status[. = 'unplugged']">unplugged, archived
  </xsl:template>

  <xsl:template match="@Status[. = 'fail']">could not be sent, not archived
  </xsl:template>

  <xsl:template match="@WorkflowStatus"><xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="@WorkflowStatus[. = 'updated']">workflow status changed
  </xsl:template>

  <xsl:template match="@WorkflowStatus[. = 'failed']">failed to change workflow status
  </xsl:template>

  <xsl:template match="Template">
    <xsl:variable name="key" select="."/>
    <xsl:value-of select="//Message[@Key = $key]/text()"/>
  </xsl:template>

  <xsl:template match="Id">
    <xsl:variable name="id" select="."/>
    <xsl:value-of select="//Message[@Id = $id]/text()"/>
  </xsl:template>

  <xsl:template match="To[last()]"><xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="To"><xsl:value-of select="."/>,<xsl:text> </xsl:text>
  </xsl:template>
  
</xsl:stylesheet>

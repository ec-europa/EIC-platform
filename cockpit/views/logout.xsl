<?xml version="1.0" encoding="UTF-8"?>
<!--
    Cockpit - EIC SME Dashboard Application

    Login form generation

    Author: Stéphane Sire <s.sire@free.fr>

    Turns a <Login> model to a <site:content> module containing a login dialog
    box. Does nothing if the model contains a <Redirected> element (e.g. as a
    consequence of a successful login when handling a POST - see login.xql).

     September 2015 - European Union Public Licence EUPL
  -->

<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site"
  xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>

  <!-- integrated URL rewriting... -->
  <xsl:param name="xslt.base-url"></xsl:param>

  <xsl:template match="/Logout">
    <site:view skin="fonts">
      <site:window><title>SME Dashboard</title></site:window>
      <site:model>
        <Navigation xmlns="">
          <Mode>dashboard</Mode>
          <Name>SME Dashboard</Name>
        </Navigation>
      </site:model>
      <site:content>
        <div class="row login">
          <div class="span8">
            <fieldset>
              <legend>Successful Logout</legend>
              <p>See U soon!</p>
            </fieldset>
          </div>
        </div>
        <xsl:apply-templates select="@LogoutAll"/>
      </site:content>
    </site:view>
  </xsl:template>

  <xsl:template match="@LogoutAll">
    <div class="row login">
      <div class="span12">
        <blockquote>
          <p>Before you leave the computer it is important to log out of EU login especially if the computer is accessible to others (eg. Internet café).</p>
          <br/>
          <p>In order to do so please <a href="{ . }">Logout EU Login</a></p>
          <br/>
          <p>Make sure to also close all tabs and windows you used to navigate to other pages of the Business Acceleration Services.</p>
        </blockquote>
      </div>
    </div>
  </xsl:template>
</xsl:stylesheet>

<?xml version="1.0" encoding="UTF-8"?>
<!--

     Author: Stéphane Sire <s.sire@opppidoc.fr>

     Converts Cases exported to XML from EASME Excel file using Oxygen XML
     to pivot Case Tracker XML batch file format

     Adjusts match rules to adapt to EASME column names as required (!)

     Use : 
     1) apply manually using Oxygen XML editor
     2) do not forget to edit Call element after transformation

     February 2016 - (c) Copyright may be reserved
  -->
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="xml" media-type="text/xml" omit-xml-declaration="yes" indent="yes"/>

  <xsl:template match="/root">
    <root>
      <Call>
        <PhaseRef>1 | 2</PhaseRef>
        <Date>YYYY-MM-DD</Date>
      </Call>
      <xsl:apply-templates select="row"/>
    </root>
  </xsl:template>

  <xsl:template match="row">
    <row>
      <xsl:apply-templates select="*"/>
    </row>
  </xsl:template>

  <xsl:template match="Eval_Panel_Name">
    <Eval_Panel_Name><xsl:value-of select="."/></Eval_Panel_Name>
  </xsl:template>
 
  <!-- DEPRECATED since February 2016
  <xsl:template match="Eval_Panel_Name[starts-with(., 'BIOTEC-')]">
    <Eval_Panel_Name>BIOTECH-<xsl:value-of select="substring-after(., 'BIOTEC-')"/></Eval_Panel_Name>
  </xsl:template> -->
 
  <xsl:template match="Proposal_Number">
    <Project_Number><xsl:value-of select="."/></Project_Number>
  </xsl:template>

  <xsl:template match="Proposal_Acronym">
    <Project_Acronym><xsl:value-of select="."/></Project_Acronym>
  </xsl:template>

  <xsl:template match="Proposal_Title">
    <Project_Title><xsl:value-of select="."/></Project_Title>
  </xsl:template>

  <xsl:template match="Proposal_Abstract">
    <Abstract><xsl:value-of select="."/></Abstract>
  </xsl:template>

  <xsl:template match="Proposal_Duration">
    <Project_Duration><xsl:value-of select="."/></Project_Duration>
  </xsl:template>

  <xsl:template match="_PP__Core_Country_Name">
    <Country_Name><xsl:value-of select="."/></Country_Name>
  </xsl:template>

  <xsl:template match="Applicant_Legal_Name">
    <Participant_Legal_Name><xsl:value-of select="."/></Participant_Legal_Name>
  </xsl:template>

  <xsl:template match="Applicant_Short_Name">
    <Participant_Short_Name><xsl:value-of select="."/></Participant_Short_Name>
  </xsl:template>

  <xsl:template match="Applicant_PIC">
    <Participant_PIC><xsl:value-of select="."/></Participant_PIC>
  </xsl:template>

  <xsl:template match="Applicant_Web_Page">
    <WebSite><xsl:value-of select="."/></WebSite>
  </xsl:template>

  <xsl:template match="_PP__Core_Legal_Registration_Date">
    <Legal_Registration_Date><xsl:value-of select="."/></Legal_Registration_Date>
  </xsl:template>

  <xsl:template match="Number_of_Employees">
    <Nbr_Of_Employees><xsl:value-of select="."/></Nbr_Of_Employees>
  </xsl:template>

  <xsl:template match="Applicant_Street">
    <Contact_Street><xsl:value-of select="."/></Contact_Street>
  </xsl:template>

  <xsl:template match="Applicant_Postal_Code">
    <Contact_Postal_Code><xsl:value-of select="."/></Contact_Postal_Code>
  </xsl:template>

  <xsl:template match="Applicant_City">
    <Contact_City><xsl:value-of select="."/></Contact_City>
  </xsl:template>

  <xsl:template match="Appl_Main_Pers_Title">
    <Contact_Title><xsl:value-of select="."/></Contact_Title>
  </xsl:template>

  <xsl:template match="Appl_Main_Pers_First_Name">
    <Contact_First_Name><xsl:value-of select="."/></Contact_First_Name>
  </xsl:template>

  <xsl:template match="Appl_Main_Pers_Last_Name">
    <Contact_Last_Name><xsl:value-of select="."/></Contact_Last_Name>
  </xsl:template>

  <xsl:template match="Appl_Main_Pers_Gender">
    <Contact_Gender><xsl:value-of select="."/></Contact_Gender>
  </xsl:template>

  <xsl:template match="Appl_Main_Pers_Position">
    <Contact_Postition><xsl:value-of select="."/></Contact_Postition>
  </xsl:template>

  <xsl:template match="Appl_Main_Pers_Department[. != '']">
    <Contact_Department><xsl:value-of select="."/></Contact_Department>
  </xsl:template>
 
  <xsl:template match="Appl_Main_Pers_Department[. = '']">
  </xsl:template>
 
  <xsl:template match="Appl_Main_Pers_Phone1[. != '']">
    <Contact_Phone1><xsl:value-of select="."/></Contact_Phone1>
  </xsl:template>
 
  <xsl:template match="Appl_Main__Pers_Phone1[. = '']">
  </xsl:template>

  <!-- Not available any more 
  <xsl:template match="Appl_Main_Pers_Phone2">
    <Contact_Phone2><xsl:value-of select="."/></Contact_Phone2>
  </xsl:template>-->

  <xsl:template match="Appl_Main_Pers_Email">
    <Contact_Email><xsl:value-of select="."/></Contact_Email>
  </xsl:template>

  <xsl:template match="PO_ID_">
    <PO_ID><xsl:value-of select="."/></PO_ID>
  </xsl:template>

  <!-- Not available any more 
    <xsl:template match="Nace">
      <Nace><xsl:value-of select="."/></Nace>
    </xsl:template>-->
 
  <xsl:template match="*">
  </xsl:template>
</xsl:stylesheet>

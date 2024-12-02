<?xml version="1.0" ?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output omit-xml-declaration="yes" indent="yes"/>

  <xsl:template match="@* | node()">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>

%{if nic_model != null }
  <xsl:template match="/domain/devices/interface[@type='bridge']/model/@type">
    <xsl:attribute name="type">
      <xsl:value-of select="'${nic_model}'"/>
    </xsl:attribute>
  </xsl:template>
%{endif}

%{if length(hugepages) > 0 }
  <xsl:template match="domain">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
      <memoryBacking>
        <hugepages>
%{for hp in hugepages}
          <page size="${hp.size}" unit="${hp.unit}" />
%{endfor}
        </hugepages>
      </memoryBacking>
    </xsl:copy>
  </xsl:template>
%{endif}

</xsl:stylesheet>

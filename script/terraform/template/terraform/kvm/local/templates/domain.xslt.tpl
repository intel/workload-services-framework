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
          <page size="${hp.size}" unit="${hp.unit}" %{if node_set != "" }nodeset="${node_set}"%{endif} />
%{endfor}
        </hugepages>
      </memoryBacking>
    </xsl:copy>
  </xsl:template>
%{endif}

  <xsl:template match="domain/features">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()[not(local-name()=('pmu'))]" />
      <pmu state="on" />
    </xsl:copy>
  </xsl:template>

%{if cpu_set != "" }
  <xsl:template match="domain/vcpu">
    <xsl:copy>
      <xsl:attribute name="placement">%{if cpu_set != "auto" }static%{else}auto%{endif}</xsl:attribute>
      %{if cpu_set != "auto" }
      <xsl:attribute name="cpuset">${cpu_set}</xsl:attribute>
      %{endif}
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>
%{endif}

%{if node_set != "" }
  <xsl:template match="domain">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
      <numatune>
        <memory placement="%{if node_set != "auto" }static%{else}auto%{endif}" %{if node_set != "auto" }nodeset="${node_set}"%{endif} />
      </numatune>
    </xsl:copy>
  </xsl:template>
%{endif}

%{for disk in nvme_disks }
  <xsl:template match="domain/devices/disk[@type='block'][@device='disk'][target/@dev='${disk.device}']">
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <source>
        <address domain='0x${disk.pci[0]}' bus='0x${disk.pci[1]}' slot='0x${split(".",disk.pci[2])[0]}' function='0x${split(".",disk.pci[2])[1]}'/>
      </source>
    </hostdev>
  </xsl:template>
%{endfor}

</xsl:stylesheet>

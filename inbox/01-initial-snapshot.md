# 01 — Initial snapshot

Captured by `_helpers\snapshot.ps1` on the test PC, run from an elevated PS 5.1
console. Read-only — nothing was installed or modified. Raw output is in
[`inbox/01-snapshot-raw.txt`](01-snapshot-raw.txt); 1,940 dd_*.log files +
the bootstrap log are in [`inbox/logs/`](logs/) (~151 MB on disk).

## TL;DR

- **vs_BuildTools.exe exited 0** at 02:05:06 yesterday but the C++ workload didn't
  register. `vswhere -all -prerelease -format json` returns `[]`.
- **Yet `_Instances` has one entry** — `0240ddbe`, `LastWriteTime 10.05.2026 02:05:03`
  — so the installer wrote *something* and then did not finalize.
- **Install folder `D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools`
  exists** with **10,436 entries recursive** including a `VC` directory (top-level
  mtime `02:03:55`, predates the `_Instances` write by ~70 s). Files were
  unpacked but the install was never committed.
- **All four wanted dd_*.log files survived in `%TEMP%`**, including the 5,214,965-byte
  `dd_installer_elevated_20260510020313.log` from the most recent attempt.
- **Bootstrap log present**, 2,804 bytes; tail confirms the bootstrap script's
  own `vswhere` check caught the missing component and fired its `[ERROR]` path.
- One in-flight `TrustedInstaller.exe` was running at the moment of capture
  (started 11:37:44, i.e. during the snapshot run, not from yesterday's attempts).
  Probably unrelated.

## Environment

```text
===== OSVersion.VersionString =====
Microsoft Windows NT 10.0.26200.0

===== PSVersionTable =====


Name  : PSVersion
Value : 5.1.26100.8115

Name  : PSEdition
Value : Desktop

Name  : PSCompatibleVersions
Value : {1.0, 2.0, 3.0, 4.0...}

Name  : BuildVersion
Value : 10.0.26100.8115

Name  : CLRVersion
Value : 4.0.30319.42000

Name  : WSManStackVersion
Value : 3.0

Name  : PSRemotingProtocolVersion
Value : 2.3

Name  : SerializationVersion
Value : 1.1.0.1

===== Get-ComputerInfo (selected) =====


OsName             : Microsoft Windows 11 Home
OsVersion          : 10.0.26200
OsBuildNumber      : 26200
WindowsProductName : Windows 10 Home
OsArchitecture     : 64-biters
```

## Disk space

```text
===== Get-PSDrive (FileSystem) =====

Name FreeGB UsedGB
---- ------ ------
C     847,3    105
D    1818,8   44,2

```

## VS install state

### `vswhere -all -prerelease -format json`

```text
[]

```

Empty array — vswhere reports zero installed instances.

### `_Instances` directory

```text

Name     LastWriteTime      
----     -------------      
0240ddbe 10.05.2026 02:05:03

```

One folder present despite vswhere returning empty. The mtime `02:05:03` is ~3 s before the bootstrap log records `vs_BuildTools exit code: 0` at `02:05:06.4435`. This is the "ghost instance" pattern from the debug doc.

### `svn` sanity

```text


Source  : C:\Program Files\TortoiseSVN\bin\svn.exe
Version : 1.14.5.21638

```

TortoiseSVN 1.14.5.21638 already on PATH — bootstrap script will skip its own SVN install step.

## Surviving diagnostic logs

### Wanted files (per `outbox/01-initial-brief.md`)

```text
FOUND   dd_installer_20260510021008.log (19130 bytes)
FOUND   dd_installer_elevated_20260510020313.log (5214965 bytes)
FOUND   dd_setup_20260510021015.log (7846 bytes)
FOUND   dd_setup_20260510021015_errors.log (0 bytes)
```

All four found, all four copied to `inbox/logs/`. The 5.2 MB
`dd_installer_elevated_20260510020313.log` is the one most likely to contain
the failure signal from the last attempt.

### Full dd_*.log inventory in `%TEMP%`

The brief also asked for the full `dd_*.log` inventory sorted newest-first.
Summarized first because the raw `Format-Table` output is ~1,940 rows.

| Prefix                       | Count |  Approx total size |
|------------------------------|-------|--------------------|
| dd_setup                     |  1914 |          112.1 MB |
| dd_installer_elevated        |     8 |           31.5 MB |
| dd_installer (non-elevated)  |     9 |            0.3 MB |
| dd_bootstrapper              |     5 |            0.0 MB |
| dd_vcredist_x86              |     3 |            0.4 MB |

(`dd_setup` count is large because each VS package logs separately — there
are ~235 packages per attempt, and there were ~8 attempts yesterday between
00:49 and 02:13. Not all attempts produced complete sets.)

#### Per-attempt timestamp clusters (from log filename prefixes)

```text
20260510004929
20260510005913
20260510010141
20260510012325
20260510013544
20260510014437
20260510014457
20260510020313
```

Eight elevated-installer attempts on 2026-05-10 between 00:49:29 and 02:03:13.
Each ran ~1-3 min before exiting; the bootstrap log records that the most
recent (02:03:13 elevated phase, 02:05:06 outer exit) is the one this snapshot
was taken after.

#### Full Format-Table output (for completeness)

<details><summary>Click to expand the full PS Format-Table listing (~1,944 rows)</summary>

```text
Name                                                                                                LastWriteTime        Length
----                                                                                                -------------        ------
dd_installer_20260510021008.log                                                                     10.05.2026 02:10:35   19130
dd_setup_20260510021015.log                                                                         10.05.2026 02:10:16    7846
dd_setup_20260510021015_errors.log                                                                  10.05.2026 02:10:15       0
dd_bootstrapper_20260510020307.log                                                                  10.05.2026 02:05:05    5767
dd_installer_20260510020309.log                                                                     10.05.2026 02:05:05   45620
dd_installer_elevated_20260510020313.log                                                            10.05.2026 02:05:05 5214965
dd_setup_20260510020504.log                                                                         10.05.2026 02:05:05    8310
dd_setup_20260510020504_errors.log                                                                  10.05.2026 02:05:04       0
dd_setup_20260510020314.log                                                                         10.05.2026 02:05:04 4583051
dd_setup_20260510020314_238_Win11SDK_10.0.22621.log                                                 10.05.2026 02:05:01     719
dd_setup_20260510020314_237_Microsoft.VisualStudio.VC.Ide.Linux.ConnectionManager.log               10.05.2026 02:03:59   17991
dd_setup_20260510020314_236_Microsoft.VisualStudio.VC.Ide.Linux.Shared.log                          10.05.2026 02:03:59    1182
dd_setup_20260510020314_235_Microsoft.VisualStudio.VC.Ide.Linux.Shared.Resources.log                10.05.2026 02:03:59    1260
dd_setup_20260510020314_234_Microsoft.VisualStudio.VC.Ide.Linux.ConnectionManager.Resources.log     10.05.2026 02:03:59   11403
dd_setup_20260510020314_233_Microsoft.VisualStudio.TestTools.TestWIExtension.log                    10.05.2026 02:03:59    3984
dd_setup_20260510020314_232_Microsoft.VisualStudio.TestTools.TestPlatform.IDE.log                   10.05.2026 02:03:58 1056826
dd_setup_20260510020314_231_Microsoft.VisualStudio.VC.Templates.UnitTest.log                        10.05.2026 02:03:56    8256
dd_setup_20260510020314_230_Microsoft.VisualStudio.VC.Templates.UnitTest.Resources.log              10.05.2026 02:03:56    4968
dd_setup_20260510020314_229_Microsoft.VisualStudio.VC.Templates.Desktop.log                         10.05.2026 02:03:56   18816
dd_setup_20260510020314_228_Microsoft.VisualStudio.VC.Ide.Pro.log                                   10.05.2026 02:03:56     309
dd_setup_20260510020314_227_Microsoft.VisualStudio.VC.Ide.Pro.Resources.log                         10.05.2026 02:03:56   15780
dd_setup_20260510020314_226_Microsoft.VisualStudio.VC.Templates.General.log                         10.05.2026 02:03:56   45459
dd_setup_20260510020314_225_Microsoft.VisualStudio.VC.Templates.General.Resources.log               10.05.2026 02:03:56   13692
dd_setup_20260510020314_224_Microsoft.VisualStudio.VC.Items.Pro.log                                 10.05.2026 02:03:56    4098
dd_setup_20260510020314_223_Microsoft.VisualStudio.VC.Ide.MDD.log                                   10.05.2026 02:03:56   21816
dd_setup_20260510020314_222_Microsoft.VisualStudio.CodeSense.Community.log                          10.05.2026 02:03:56    7282
dd_setup_20260510020314_221_Microsoft.VisualStudio.TestTools.TeamFoundationClient.log               10.05.2026 02:03:56   39528
dd_setup_20260510020314_220_Microsoft.VisualStudio.AppResponsiveness.log                            10.05.2026 02:03:56   51195
dd_setup_20260510020314_219_Microsoft.VisualStudio.AppResponsiveness.Targeted.log                   10.05.2026 02:03:56    1392
dd_setup_20260510020314_218_Microsoft.VisualStudio.AppResponsiveness.Resources.log                  10.05.2026 02:03:56    3786
dd_setup_20260510020314_217_Microsoft.VisualStudio.ClientDiagnostics.log                            10.05.2026 02:03:56   11898
dd_setup_20260510020314_216_Microsoft.VisualStudio.ClientDiagnostics.Targeted.log                   10.05.2026 02:03:56    2139
dd_setup_20260510020314_215_Microsoft.VisualStudio.ClientDiagnostics.Resources.log                  10.05.2026 02:03:56    1452
dd_setup_20260510020314_214_Microsoft.VisualStudio.ProjectSystem.Full.log                           10.05.2026 02:03:56     594
dd_setup_20260510020314_213_Microsoft.VisualStudio.LiveShareApi.log                                 10.05.2026 02:03:55    1260
dd_setup_20260510020314_212_Microsoft.VisualStudio.ProjectSystem.Query.log                          10.05.2026 02:03:55   31131
dd_setup_20260510020314_211_Microsoft.VisualStudio.ProjectSystem.log                                10.05.2026 02:03:55   49894
dd_setup_20260510020314_210_Microsoft.VisualStudio.Community.x86.log                                10.05.2026 02:03:55    3567
dd_setup_20260510020314_209_Microsoft.VisualStudio.Community.x64.log                                10.05.2026 02:03:55    3393
dd_setup_20260510020314_208_Microsoft.VisualStudio.Community.VB.Targeted.log                        10.05.2026 02:03:55    2667
dd_setup_20260510020314_207_Microsoft.VisualStudio.Community.VB.Neutral.log                         10.05.2026 02:03:55   10062
dd_setup_20260510020314_206_Microsoft.VisualStudio.Community.CSharp.Targeted.log                    10.05.2026 02:03:55    4347
dd_setup_20260510020314_205_Microsoft.VisualStudio.Community.CSharp.Neutral.log                     10.05.2026 02:03:55   21120
dd_setup_20260510020314_204_Microsoft.VisualStudio.Community.ProductArch.TargetedExtra.log          10.05.2026 02:03:55    4122
dd_setup_20260510020314_203_Microsoft.VisualStudio.Community.ProductArch.Targeted.log               10.05.2026 02:03:55   28655
dd_setup_20260510020314_202_Microsoft.VisualStudio.Community.ProductArch.NeutralExtra.log           10.05.2026 02:03:55   13500
dd_setup_20260510020314_201_Microsoft.IntelliTrace.CollectorCab.log                                 10.05.2026 02:03:54    2169
dd_setup_20260510020314_200_Microsoft.VisualStudio.Community.VB.Resources.Targeted.log              10.05.2026 02:03:54    2190
dd_setup_20260510020314_199_Microsoft.VisualStudio.Community.VB.Resources.Neutral.log               10.05.2026 02:03:54  314136
dd_setup_20260510020314_198_Microsoft.VisualStudio.Community.CSharp.Resources.Targeted.log          10.05.2026 02:03:54     972
dd_setup_20260510020314_197_Microsoft.VisualStudio.Community.CSharp.Resources.Neutral.log           10.05.2026 02:03:54   56763
dd_setup_20260510020314_196_Microsoft.VisualStudio.Community.ProductArch.Resources.Targeted.log     10.05.2026 02:03:54    9147
dd_setup_20260510020314_195_Microsoft.VisualStudio.Community.ProductArch.Resources.NeutralExtra.log 10.05.2026 02:03:54   33943
dd_setup_20260510020314_194_Microsoft.VisualStudio.Community.ProductArch.Resources.Neutral.log      10.05.2026 02:03:54   46611
dd_setup_20260510020314_193_Microsoft.VisualStudio.WebSiteProject.DTE.log                           10.05.2026 02:03:54    2616
dd_setup_20260510020314_192_Microsoft.VisualStudio.Diagnostics.AspNetHelper.log                     10.05.2026 02:03:54     309
dd_setup_20260510020314_191_Microsoft.MSHtml.log                                                    10.05.2026 02:03:54    1062
dd_setup_20260510020314_190_Microsoft.VisualStudio.Platform.CallHierarchy.log                       10.05.2026 02:03:54   18894
dd_setup_20260510020314_189_Microsoft.VisualStudio.Community.ProductArch.Neutral.log                10.05.2026 02:03:54  132431
dd_setup_20260510020314_188_Microsoft.VisualStudio.Community.Msi.Resources.log                      10.05.2026 02:03:53   88276
dd_setup_20260510020314_187_Microsoft.VisualStudio.Community.Msi.log                                10.05.2026 02:03:53  292840
dd_setup_20260510020314_186_Microsoft.VisualStudio.Community.Shared.Msi.log                         10.05.2026 02:03:53  688186
dd_setup_20260510020314_185_Microsoft.VisualStudio.MinShell.Interop.Msi.log                         10.05.2026 02:03:51 1807804
dd_setup_20260510020314_184_Microsoft.VisualStudio.MinShell.Interop.Shared.Msi.log                  10.05.2026 02:03:49  456570
dd_setup_20260510020314_183_Microsoft.DiagnosticsHub.Runtime.log                                    10.05.2026 02:03:48  103872
dd_setup_20260510020314_182_Microsoft.DiagnosticsHub.Collection.log                                 10.05.2026 02:03:48   14631
dd_setup_20260510020314_181_Microsoft.DiagnosticsHub.Collection.Service.log                         10.05.2026 02:03:48  129014
dd_setup_20260510020314_180_Microsoft.VisualStudio.ScriptedHost.log                                 10.05.2026 02:03:48    4671
dd_setup_20260510020314_179_Microsoft.VisualStudio.ScriptedHost.Targeted.log                        10.05.2026 02:03:48    1056
dd_setup_20260510020314_178_Microsoft.VisualStudio.VirtualTree.log                                  10.05.2026 02:03:48    1200
dd_setup_20260510020314_177_Microsoft.VisualStudio.PerformanceProvider.log                          10.05.2026 02:03:48    1673
dd_setup_20260510020314_176_Microsoft.VisualStudio.GraphModel.log                                   10.05.2026 02:03:48    2352
dd_setup_20260510020314_175_Microsoft.VisualStudio.GraphProvider.log                                10.05.2026 02:03:47   13615
dd_setup_20260510020314_174_Microsoft.VisualStudio.GraphProvider.Auto.log                           10.05.2026 02:03:47    7084
dd_setup_20260510020314_173_Microsoft.VisualStudio.TextMateGrammars.log                             10.05.2026 02:03:47  318581
dd_setup_20260510020314_172_Microsoft.VisualStudio.Platform.Markdown.log                            10.05.2026 02:03:47   34233
dd_setup_20260510020314_171_Microsoft.ServiceHub.Node.log                                           10.05.2026 02:03:47    5103
dd_setup_20260510020314_170_Microsoft.ServiceHub.Managed.log                                        10.05.2026 02:03:47   48738
dd_setup_20260510020314_169_Microsoft.VisualStudio.OpenFolder.VSIX.log                              10.05.2026 02:03:47   94695
dd_setup_20260510020314_168_Microsoft.VisualStudio.FileHandler.Msi.log                              10.05.2026 02:03:47  132228
dd_setup_20260510020314_167_Microsoft.VisualStudio.FileHandler.Msi.log                              10.05.2026 02:03:46  166576
dd_setup_20260510020314_166_Microsoft.VisualStudio.MinShell.Msi.log                                 10.05.2026 02:03:46   83308
dd_setup_20260510020314_165_Microsoft.VisualStudio.MinShell.Shared.Msi.log                          10.05.2026 02:03:46  104248
dd_setup_20260510020314_164_Microsoft.VisualStudio.MinShell.Msi.Resources.log                       10.05.2026 02:03:45   88436
dd_setup_20260510020314_163_Microsoft.VisualStudio.MinShell.Interop.log                             10.05.2026 02:03:45   41507
dd_setup_20260510020314_162_Microsoft.VisualStudio.NgenRunner.log                                   10.05.2026 02:03:45    1605
dd_setup_20260510020314_161_Microsoft.VisualStudio.Log.log                                          10.05.2026 02:03:45   11798
dd_setup_20260510020314_160_Microsoft.VisualStudio.Log.Targeted.log                                 10.05.2026 02:03:45    1146
dd_setup_20260510020314_159_Microsoft.VisualStudio.Log.Resources.log                                10.05.2026 02:03:45     936
dd_setup_20260510020314_158_Microsoft.VisualStudio.Finalizer.log                                    10.05.2026 02:03:45   11253
dd_setup_20260510020314_157_Microsoft.VisualStudio.ErrorList.log                                    10.05.2026 02:03:45   16597
dd_setup_20260510020314_156_Microsoft.VisualStudio.CoreEditor.log                                   10.05.2026 02:03:45   25707
dd_setup_20260510020314_155_Microsoft.VisualStudio.CoreEditor.UserProfiles.log                      10.05.2026 02:03:45    5088
dd_setup_20260510020314_154_Microsoft.VisualStudio.Platform.NavigateTo.log                          10.05.2026 02:03:44    5085
dd_setup_20260510020314_153_Microsoft.VisualStudio.Connected.log                                    10.05.2026 02:03:44   29386
dd_setup_20260510020314_152_Microsoft.VisualStudio.Identity.log                                     10.05.2026 02:03:44  491097
dd_setup_20260510020314_151_Microsoft.Developer.IdentityServiceGS.log                               10.05.2026 02:03:43   16167
dd_setup_20260510020314_150_SQLitePCLRaw.log                                                        10.05.2026 02:03:42    4925
dd_setup_20260510020314_149_SQLitePCLRaw.Targeted.log                                               10.05.2026 02:03:42    1206
dd_setup_20260510020314_148_Microsoft.VisualStudio.Connected.Auto.log                               10.05.2026 02:03:42    3741
dd_setup_20260510020314_147_Microsoft.VisualStudio.Connected.Auto.Resources.log                     10.05.2026 02:03:42    1278
dd_setup_20260510020314_146_Microsoft.VisualStudio.Connected.Resources.log                          10.05.2026 02:03:42     309
dd_setup_20260510020314_145_Microsoft.VisualStudio.VC.Ide.x64.log                                   10.05.2026 02:03:42    1020
dd_setup_20260510020314_144_Microsoft.VisualStudio.Debugger.Script.Msi.log                          10.05.2026 02:03:42 1700486
dd_setup_20260510020314_143_Microsoft.VisualStudio.Debugger.Script.log                              10.05.2026 02:03:40    2802
dd_setup_20260510020314_142_Microsoft.VisualStudio.Debugger.Script.Resources.log                    10.05.2026 02:03:40    1140
dd_setup_20260510020314_141_Microsoft.VisualStudio.Debugger.Script.Remote.log                       10.05.2026 02:03:40    1929
dd_setup_20260510020314_140_Microsoft.VisualStudio.Debugger.Script.Remote.log                       10.05.2026 02:03:40    1917
dd_setup_20260510020314_139_Microsoft.VisualStudio.Debugger.Script.Remote.Resources.log             10.05.2026 02:03:40    1182
dd_setup_20260510020314_138_Microsoft.VisualStudio.Debugger.Script.Remote.Resources.log             10.05.2026 02:03:40    1182
dd_setup_20260510020314_137_Microsoft.VisualStudio.VC.Ide.WinXPlus.log                              10.05.2026 02:03:40   19857
dd_setup_20260510020314_136_Microsoft.VisualStudio.VC.Ide.Dskx.log                                  10.05.2026 02:03:40    4914
dd_setup_20260510020314_135_Microsoft.VisualStudio.VC.Ide.Dskx.Resources.log                        10.05.2026 02:03:40    1623
dd_setup_20260510020314_134_Microsoft.VisualStudio.VC.Ide.Base.log                                  10.05.2026 02:03:40  119658
dd_setup_20260510020314_133_Microsoft.VisualStudio.VC.Ide.LanguageService.log                       10.05.2026 02:03:39   53309
dd_setup_20260510020314_132_Microsoft.VisualStudio.VC.Copilot.Setup.log                             10.05.2026 02:03:39    4227
dd_setup_20260510020314_131_Microsoft.VisualStudio.VC.Ide.VCPkgDatabase.log                         10.05.2026 02:03:39    1164
dd_setup_20260510020314_130_Microsoft.VisualStudio.VC.Ide.ResourceEditor.log                        10.05.2026 02:03:39   11892
dd_setup_20260510020314_129_Microsoft.VisualStudio.VC.Ide.ResourceEditor.Resources.log              10.05.2026 02:03:39    3219
dd_setup_20260510020314_128_Microsoft.VisualStudio.VC.Ide.LanguageService.Dependencies.log          10.05.2026 02:03:39    2199
dd_setup_20260510020314_127_Microsoft.VisualStudio.VC.Ide.Core.log                                  10.05.2026 02:03:39    6327
dd_setup_20260510020314_126_Microsoft.VisualStudio.VisualC.Utilities.log                            10.05.2026 02:03:39    2103
dd_setup_20260510020314_125_Microsoft.VisualStudio.VisualC.Utilities.Resources.log                  10.05.2026 02:03:39     309
dd_setup_20260510020314_124_Microsoft.VisualStudio.VC.Ide.ProjectSystem.log                         10.05.2026 02:03:39   18272
dd_setup_20260510020314_123_Microsoft.VisualStudio.VC.Ide.ProjectSystem.Resources.log               10.05.2026 02:03:38    4350
dd_setup_20260510020314_122_Microsoft.VisualStudio.VC.Ide.Core.VCProjectEngine.log                  10.05.2026 02:03:38    1194
dd_setup_20260510020314_121_Microsoft.VisualStudio.VC.Ide.Core.VCProjectEngine.Resources.log        10.05.2026 02:03:38    1212
dd_setup_20260510020314_120_Microsoft.VisualStudio.VC.Ide.LanguageService.Resources.log             10.05.2026 02:03:38   45036
dd_setup_20260510020314_119_Microsoft.VisualStudio.VC.Llvm.Base.log                                 10.05.2026 02:03:38   78315
dd_setup_20260510020314_118_Microsoft.VisualStudio.VC.Ide.Base.Resources.log                        10.05.2026 02:03:37    3663
dd_setup_20260510020314_117_Microsoft.VisualStudio.Debugger.BrokeredServices.log                    10.05.2026 02:03:37   17449
dd_setup_20260510020314_116_Microsoft.VisualStudio.Debugger.VSCodeDebuggerHost.log                  10.05.2026 02:03:37   21441
dd_setup_20260510020314_115_Microsoft.VisualStudio.Debugger.AzureAttach.log                         10.05.2026 02:03:37    2373
dd_setup_20260510020314_114_Microsoft.VisualStudio.Web.Azure.Common.log                             10.05.2026 02:03:37    9699
dd_setup_20260510020314_113_Microsoft.WebTools.Shared.log                                           10.05.2026 02:03:37  415675
dd_setup_20260510020314_112_Microsoft.WebTools.DotNet.Core.ItemTemplates.log                        10.05.2026 02:03:36    7392
dd_setup_20260510020314_111_Microsoft.VisualStudio.VC.Ide.Debugger.log                              10.05.2026 02:03:36   23592
dd_setup_20260510020314_110_Microsoft.VisualStudio.VC.Ide.Debugger.Concord.log                      10.05.2026 02:03:36    3507
dd_setup_20260510020314_109_Microsoft.VisualStudio.VC.Ide.Debugger.Concord.Resources.log            10.05.2026 02:03:36    1713
dd_setup_20260510020314_108_Microsoft.VisualStudio.VC.Ide.Debugger.Resources.log                    10.05.2026 02:03:36    1857
dd_setup_20260510020314_107_Microsoft.VisualStudio.VC.Ide.Common.log                                10.05.2026 02:03:36   11508
dd_setup_20260510020314_106_Microsoft.VisualStudio.VC.Ide.Common.Resources.log                      10.05.2026 02:03:36    1677
dd_setup_20260510020314_105_Microsoft.VisualStudio.Debugger.CollectionAgents.log                    10.05.2026 02:03:36    2073
dd_setup_20260510020314_104_Microsoft.VisualStudio.Debugger.Parallel.log                            10.05.2026 02:03:36    7208
dd_setup_20260510020314_103_Microsoft.VisualStudio.Debugger.Parallel.Resources.log                  10.05.2026 02:03:36    1182
dd_setup_20260510020314_102_Microsoft.VisualStudio.Debugger.Managed.log                             10.05.2026 02:03:36   43959
dd_setup_20260510020314_101_Microsoft.DiaSymReader.log                                              10.05.2026 02:03:36    1104
dd_setup_20260510020314_100_Microsoft.CodeAnalysis.ExpressionEvaluator.log                          10.05.2026 02:03:36   51786
dd_setup_20260510020314_099_Microsoft.VisualStudio.Debugger.Concord.Managed.log                     10.05.2026 02:03:36   10304
dd_setup_20260510020314_098_Microsoft.VisualStudio.Debugger.Concord.Managed.Resources.log           10.05.2026 02:03:36     309
dd_setup_20260510020314_097_Microsoft.VisualStudio.Debugger.Managed.Resources.log                   10.05.2026 02:03:36    2013
dd_setup_20260510020314_096_Microsoft.VisualStudio.Debugger.TargetComposition.log                   10.05.2026 02:03:35    2202
dd_setup_20260510020314_095_Microsoft.VisualStudio.Debugger.TargetComposition.Remote.log            10.05.2026 02:03:35    2580
dd_setup_20260510020314_094_Microsoft.VisualStudio.Debugger.TargetComposition.Remote.log            10.05.2026 02:03:35    2580
dd_setup_20260510020314_093_Microsoft.VisualStudio.Debugger.Remote.log                              10.05.2026 02:03:35   76719
dd_setup_20260510020314_092_Microsoft.VisualStudio.Debugger.Concord.Remote.log                      10.05.2026 02:03:35   14805
dd_setup_20260510020314_091_Microsoft.VisualStudio.Debugger.Concord.Remote.Resources.log            10.05.2026 02:03:35    1170
dd_setup_20260510020314_090_Microsoft.VisualStudio.Debugger.Remote.log                              10.05.2026 02:03:35   77562
dd_setup_20260510020314_089_Microsoft.VisualStudio.Debugger.Concord.Remote.log                      10.05.2026 02:03:35   13134
dd_setup_20260510020314_088_Microsoft.VisualStudio.Debugger.Concord.Remote.Resources.log            10.05.2026 02:03:35    1170
dd_setup_20260510020314_087_Microsoft.VisualStudio.Debugger.Remote.Resources.log                    10.05.2026 02:03:35    2670
dd_setup_20260510020314_086_Microsoft.VisualStudio.Debugger.Remote.Resources.log                    10.05.2026 02:03:35    3495
dd_setup_20260510020314_085_Microsoft.VisualStudio.Debugger.log                                     10.05.2026 02:03:35   77822
dd_setup_20260510020314_084_Microsoft.VisualStudio.AzureSDK.log                                     10.05.2026 02:03:34    8316
dd_setup_20260510020314_083_Microsoft.VisualStudio.Editors.log                                      10.05.2026 02:03:34   30075
dd_setup_20260510020314_082_Microsoft.VisualStudio.VC.MSVCDis.log                                   10.05.2026 02:03:34     924
dd_setup_20260510020314_081_Microsoft.IntelliTrace.DiagnosticsHub.log                               10.05.2026 02:03:34   14729
dd_setup_20260510020314_080_Microsoft.VisualStudio.MinShell.log                                     10.05.2026 02:03:34   90275
dd_setup_20260510020314_079_Microsoft.VisualStudio.OpenTelemetry.Collector.netfx.log                10.05.2026 02:03:34    1446
dd_setup_20260510020314_078_Microsoft.VisualStudio.OpenTelemetry.ClientExtensions.netfx.log         10.05.2026 02:03:34    4677
dd_setup_20260510020314_077_Microsoft.VisualStudio.Copilot.Contracts.log                            10.05.2026 02:03:34    9663
dd_setup_20260510020314_076_Microsoft.VisualStudio.Licensing.log                                    10.05.2026 02:03:34    2142
dd_setup_20260510020314_075_Microsoft.VisualStudio.IdentityDependencies.log                         10.05.2026 02:03:34   10335
dd_setup_20260510020314_074_Microsoft.VisualStudio.GitHubProtocolHandler.Msi.log                    10.05.2026 02:03:34   98328
dd_setup_20260510020314_073_Microsoft.VisualStudio.VsWebProtocolSelector.Msi.log                    10.05.2026 02:03:33   93408
dd_setup_20260510020314_072_Microsoft.VisualStudio.Extensibility.Container.log                      10.05.2026 02:03:33   46635
dd_setup_20260510020314_071_Microsoft.VisualStudio.LanguageServer.log                               10.05.2026 02:03:33   37933
dd_setup_20260510020314_070_Microsoft.VisualStudio.MefHosting.log                                   10.05.2026 02:03:33    6697
dd_setup_20260510020314_069_Microsoft.VisualStudio.Initializer.log                                  10.05.2026 02:03:33    1326
dd_setup_20260510020314_068_Microsoft.VisualStudio.ExtensionManager.log                             10.05.2026 02:03:32   41128
dd_setup_20260510020314_067_Microsoft.VisualStudio.ExtensionManager.Auto.log                        10.05.2026 02:03:32    4964
dd_setup_20260510020314_066_Microsoft.VisualStudio.Platform.Editor.log                              10.05.2026 02:03:32   85085
dd_setup_20260510020314_065_Microsoft.VisualStudio.MinShell.Targeted.log                            10.05.2026 02:03:32  107187
dd_setup_20260510020314_064_Microsoft.VisualStudio.Devenv.Config.log                                10.05.2026 02:03:32     918
dd_setup_20260510020314_063_Microsoft.VisualStudio.MinShell.Resources.log                           10.05.2026 02:03:32   10477
dd_setup_20260510020314_062_Microsoft.VisualStudio.UIInternal.Guide.log                             10.05.2026 02:03:32  194262
dd_setup_20260510020314_061_Microsoft.VisualStudio.UIInternal.log                                   10.05.2026 02:03:31  116629
dd_setup_20260510020314_060_Microsoft.VisualStudio.UIInternal.Resources.log                         10.05.2026 02:03:31    1182
dd_setup_20260510020314_059_Microsoft.VisualStudio.CoreDotNet.log                                   10.05.2026 02:03:31   62586
dd_setup_20260510020314_058_Microsoft.VisualStudio.MinShell.Auto.log                                10.05.2026 02:03:31   36514
dd_setup_20260510020314_057_Microsoft.VisualStudio.MinShell.Auto.Resources.log                      10.05.2026 02:03:31    4824
dd_setup_20260510020314_056_Microsoft.VisualStudio.Debugger.Concord.log                             10.05.2026 02:03:31   22481
dd_setup_20260510020314_055_Microsoft.VisualStudio.Debugger.Concord.Resources.log                   10.05.2026 02:03:30    2157
dd_setup_20260510020314_054_Microsoft.VisualStudio.Debugger.Resources.log                           10.05.2026 02:03:30    5323
dd_setup_20260510020314_053_Microsoft.DiaSymReader.PortablePdb.log                                  10.05.2026 02:03:30    1176
dd_setup_20260510020314_052_Microsoft.VisualStudio.PerfLib.log                                      10.05.2026 02:03:30    8469
dd_setup_20260510020314_051_Microsoft.VisualStudio.Debugger.Package.DiagHub.Client.log              10.05.2026 02:03:30    1110
dd_setup_20260510020314_050_Microsoft.VisualStudio.Debugger.Remote.DiagnosticsHub.Client.log        10.05.2026 02:03:30    1152
dd_setup_20260510020314_049_Microsoft.VisualStudio.Debugger.Remote.DiagnosticsHub.Client.log        10.05.2026 02:03:30    1152
dd_setup_20260510020314_048_Microsoft.VisualStudio.TextTemplating.MSBuild.log                       10.05.2026 02:03:30   13308
dd_setup_20260510020314_047_Microsoft.VisualStudio.TextTemplating.Integration.log                   10.05.2026 02:03:30   23722
dd_setup_20260510020314_046_Microsoft.VisualStudio.TextTemplating.Core.log                          10.05.2026 02:03:30   17887
dd_setup_20260510020314_045_Microsoft.CodeAnalysis.VisualStudio.Setup.log                           10.05.2026 02:03:30  711239
dd_setup_20260510020314_044_Microsoft.VisualStudio.TextTemplating.Integration.Resources.log         10.05.2026 02:03:26     586
dd_setup_20260510020314_043_Microsoft.VisualStudio.TestTools.DynamicCodeCoverage.log                10.05.2026 02:03:26   46134
dd_setup_20260510020314_042_Microsoft.VisualStudio.InstrumentationEngine.log                        10.05.2026 02:03:26    2451
dd_setup_20260510020314_041_Microsoft.CodeCoverage.Console.Targeted.log                             10.05.2026 02:03:26   74943
dd_setup_20260510020314_040_Microsoft.VisualStudio.TestTools.TestPlatform.V1.CLI.log                10.05.2026 02:03:26    6918
dd_setup_20260510020314_039_Microsoft.VisualStudio.TestTools.TestPlatform.V2.CLI.log                10.05.2026 02:03:26  414069
dd_setup_20260510020314_038_Microsoft.VisualStudio.VC.UnitTest.Desktop.Build.Core.log               10.05.2026 02:03:25   13707
dd_setup_20260510020314_037_Microsoft.VisualStudio.TestTools.TestPlatform.V1.CPP.log                10.05.2026 02:03:25    1416
dd_setup_20260510020314_036_Microsoft.VisualCpp.Tools.Common.Utils.log                              10.05.2026 02:03:25    4581
dd_setup_20260510020314_035_Microsoft.VisualCpp.Tools.Common.Utils.Resources.log                    10.05.2026 02:03:25    1611
dd_setup_20260510020314_034_Microsoft.VisualCpp.Servicing.Redist.log                                10.05.2026 02:03:25    3681
dd_setup_20260510020314_033_Microsoft.VisualStudio.VC.vcvars.log                                    10.05.2026 02:03:25    1731
dd_setup_20260510020314_032_Microsoft.VS.VC.vcvars.x86.Shortcuts.log                                10.05.2026 02:03:25     309
dd_setup_20260510020314_031_Microsoft.VS.VC.vcvars.x64.Shortcuts.log                                10.05.2026 02:03:25     309
dd_setup_20260510020314_030_Microsoft.Windows.UniversalCRT.Redistributable.Msi.log                  10.05.2026 02:03:25  423934
dd_setup_20260510020314_029_Microsoft.VisualStudio.VC.MSBuild.v170.x86.v143.log                     10.05.2026 02:03:24    2163
dd_setup_20260510020314_028_Microsoft.VisualStudio.VC.MSBuild.v170.X86.log                          10.05.2026 02:03:24    3591
dd_setup_20260510020314_027_Microsoft.VisualStudio.VC.MSBuild.v170.X64.v143.log                     10.05.2026 02:03:24    2139
dd_setup_20260510020314_026_Microsoft.VisualStudio.VC.MSBuild.v170.X64.log                          10.05.2026 02:03:24    3543
dd_setup_20260510020314_025_Microsoft.VisualStudio.VC.MSBuild.v170.ARM.v143.log                     10.05.2026 02:03:24    2139
dd_setup_20260510020314_024_Microsoft.VisualStudio.VC.MSBuild.v170.ARM.log                          10.05.2026 02:03:24    3543
dd_setup_20260510020314_023_Microsoft.VisualStudio.VC.MSBuild.v170.Base.log                         10.05.2026 02:03:24   82602
dd_setup_20260510020314_022_Microsoft.VisualStudio.VC.MSBuild.v170.Base.Resources.log               10.05.2026 02:03:24   38712
dd_setup_20260510020314_021_Microsoft.VisualStudio.Setup.WMIProvider.log                            10.05.2026 02:03:23  124304
dd_setup_20260510020314_020_Microsoft.VisualStudio.Setup.Configuration.Interop.log                  10.05.2026 02:03:23    1272
dd_setup_20260510020314_019_Microsoft.VisualStudio.Setup.Configuration.log                          10.05.2026 02:03:23  100024
dd_setup_20260510020314_018_Microsoft.VisualStudio.VsDevCmd.Ext.NetFxSdk.log                        10.05.2026 02:03:22    1002
dd_setup_20260510020314_017_Microsoft.VisualStudio.VsDevCmd.Core.WinSdk.log                         10.05.2026 02:03:22     996
dd_setup_20260510020314_016_Microsoft.VisualStudio.VsDevCmd.Core.DotNet.log                         10.05.2026 02:03:22     996
dd_setup_20260510020314_015_Microsoft.VisualStudio.VC.DevCmd.log                                    10.05.2026 02:03:22    9594
dd_setup_20260510020314_014_Microsoft.VisualStudio.VC.DevCmd.Resources.log                          10.05.2026 02:03:22    1140
dd_setup_20260510020314_013_Microsoft.VisualStudio.BuildTools.Resources.log                         10.05.2026 02:03:22    1044
dd_setup_20260510020314_012_Microsoft.VisualStudio.Net.Eula.Resources.log                           10.05.2026 02:03:21     990
dd_setup_20260510020314_011_Microsoft.Build.Dependencies.log                                        10.05.2026 02:03:21  435036
dd_setup_20260510020314_010_Microsoft.Build.FileTracker.Msi.log                                     10.05.2026 02:03:21  187374
dd_setup_20260510020314_009_Microsoft.PythonTools.BuildCore.Vsix.log                                10.05.2026 02:03:20   15561
dd_setup_20260510020314_008_Microsoft.NuGet.Build.Tasks.Setup.log                                   10.05.2026 02:03:20    6384
dd_setup_20260510020314_007_Microsoft.CodeAnalysis.Compilers.log                                    10.05.2026 02:03:20  106164
dd_setup_20260510020314_006_Microsoft.VisualStudio.NativeImageSupport.log                           10.05.2026 02:03:20    1497
dd_setup_20260510020314_005_Microsoft.Build.log                                                     10.05.2026 02:03:20  263505
dd_setup_20260510020314_004_Microsoft.VisualStudio.NuGet.BuildTools.log                             10.05.2026 02:03:19  224253
dd_setup_20260510020314_003_Microsoft.Build.UnGAC.log                                               10.05.2026 02:03:19    1491
dd_setup_20260510020314_002_Microsoft.VisualStudio.VC.Icons.log                                     10.05.2026 02:03:19     900
dd_setup_20260510020314_000_TestMSI.log                                                             10.05.2026 02:03:16   63142
dd_setup_20260510020314_errors.log                                                                  10.05.2026 02:03:14       0
dd_setup_20260510020312.log                                                                         10.05.2026 02:03:13   11063
dd_setup_20260510020312_errors.log                                                                  10.05.2026 02:03:12       0
dd_installer_20260510013814.log                                                                     10.05.2026 01:46:43   33608
dd_installer_elevated_20260510014457.log                                                            10.05.2026 01:46:30 3343551
dd_setup_20260510014457.log                                                                         10.05.2026 01:46:30 3333907
dd_setup_20260510014457_235_Microsoft.VisualStudio.VC.Icons.log                                     10.05.2026 01:46:29     528
dd_setup_20260510014457_234_Microsoft.VisualStudio.NuGet.BuildTools.log                             10.05.2026 01:46:29   79719
dd_setup_20260510014457_233_Microsoft.Build.log                                                     10.05.2026 01:46:29   83069
dd_setup_20260510014457_232_Microsoft.VisualStudio.NativeImageSupport.log                           10.05.2026 01:46:28     747
dd_setup_20260510014457_231_Microsoft.CodeAnalysis.Compilers.log                                    10.05.2026 01:46:28   35269
dd_setup_20260510014457_230_Microsoft.NuGet.Build.Tasks.Setup.log                                   10.05.2026 01:46:27    2476
dd_setup_20260510014457_229_Microsoft.PythonTools.BuildCore.Vsix.log                                10.05.2026 01:46:27    5683
dd_setup_20260510014457_228_Microsoft.Build.FileTracker.Msi.log                                     10.05.2026 01:46:27  148168
dd_setup_20260510014457_227_Microsoft.Build.Dependencies.log                                        10.05.2026 01:46:27  156800
dd_setup_20260510014457_226_Microsoft.VisualStudio.Net.Eula.Resources.log                           10.05.2026 01:46:26     558
dd_setup_20260510014457_225_Microsoft.VisualStudio.BuildTools.Resources.log                         10.05.2026 01:46:26     576
dd_setup_20260510014457_224_Microsoft.VisualStudio.VC.DevCmd.Resources.log                          10.05.2026 01:46:26     608
dd_setup_20260510014457_223_Microsoft.VisualStudio.VC.DevCmd.log                                    10.05.2026 01:46:26    3666
dd_setup_20260510014457_222_Microsoft.VisualStudio.VsDevCmd.Core.DotNet.log                         10.05.2026 01:46:26     560
dd_setup_20260510014457_221_Microsoft.VisualStudio.VsDevCmd.Core.WinSdk.log                         10.05.2026 01:46:26     560
dd_setup_20260510014457_220_Microsoft.VisualStudio.VsDevCmd.Ext.NetFxSdk.log                        10.05.2026 01:46:26     562
dd_setup_20260510014457_219_Microsoft.VisualStudio.Setup.Configuration.log                          10.05.2026 01:46:26   85140
dd_setup_20260510014457_218_Microsoft.VisualStudio.Setup.Configuration.Interop.log                  10.05.2026 01:46:26     652
dd_setup_20260510014457_217_Microsoft.VisualStudio.Setup.WMIProvider.log                            10.05.2026 01:46:26  103968
dd_setup_20260510014457_216_Microsoft.VisualStudio.VC.MSBuild.v170.Base.Resources.log               10.05.2026 01:46:25   14132
dd_setup_20260510014457_215_Microsoft.VisualStudio.VC.MSBuild.v170.Base.log                         10.05.2026 01:46:25   29762
dd_setup_20260510014457_214_Microsoft.VisualStudio.VC.MSBuild.v170.ARM.log                          10.05.2026 01:46:25    1469
dd_setup_20260510014457_213_Microsoft.VisualStudio.VC.MSBuild.v170.ARM.v143.log                     10.05.2026 01:46:25     961
dd_setup_20260510014457_212_Microsoft.VisualStudio.VC.MSBuild.v170.X64.log                          10.05.2026 01:46:25    1469
dd_setup_20260510014457_211_Microsoft.VisualStudio.VC.MSBuild.v170.X64.v143.log                     10.05.2026 01:46:25     961
dd_setup_20260510014457_210_Microsoft.VisualStudio.VC.MSBuild.v170.X86.log                          10.05.2026 01:46:25    1485
dd_setup_20260510014457_209_Microsoft.VisualStudio.VC.MSBuild.v170.x86.v143.log                     10.05.2026 01:46:25     969
dd_setup_20260510014457_208_Microsoft.Windows.UniversalCRT.Redistributable.Msi.log                  10.05.2026 01:46:25  350688
dd_setup_20260510014457_207_Microsoft.VS.VC.vcvars.x64.Shortcuts.log                                10.05.2026 01:46:24     295
dd_setup_20260510014457_206_Microsoft.VS.VC.vcvars.x86.Shortcuts.log                                10.05.2026 01:46:24     295
dd_setup_20260510014457_205_Microsoft.VisualStudio.VC.vcvars.log                                    10.05.2026 01:46:24     825
dd_setup_20260510014457_204_Microsoft.VisualCpp.Servicing.Redist.log                                10.05.2026 01:46:24    1515
dd_setup_20260510014457_203_Microsoft.VisualCpp.Tools.Common.Utils.Resources.log                    10.05.2026 01:46:24     785
dd_setup_20260510014457_202_Microsoft.VisualCpp.Tools.Common.Utils.log                              10.05.2026 01:46:24    1851
dd_setup_20260510014457_201_Microsoft.VisualStudio.TestTools.TestPlatform.V1.CPP.log                10.05.2026 01:46:24     700
dd_setup_20260510014457_200_Microsoft.VisualStudio.VC.UnitTest.Desktop.Build.Core.log               10.05.2026 01:46:24    5110
dd_setup_20260510014457_199_Microsoft.VisualStudio.TestTools.TestPlatform.V2.CLI.log                10.05.2026 01:46:24  146033
dd_setup_20260510014457_198_Microsoft.VisualStudio.TestTools.TestPlatform.V1.CLI.log                10.05.2026 01:46:23    2654
dd_setup_20260510014457_197_Microsoft.CodeCoverage.Console.Targeted.log                             10.05.2026 01:46:23   26669
dd_setup_20260510014457_196_Microsoft.VisualStudio.InstrumentationEngine.log                        10.05.2026 01:46:23    1065
dd_setup_20260510014457_195_Microsoft.VisualStudio.TestTools.DynamicCodeCoverage.log                10.05.2026 01:46:23   16382
dd_setup_20260510014457_194_Microsoft.VisualStudio.TextTemplating.Integration.Resources.log         10.05.2026 01:46:22     594
dd_setup_20260510014457_193_Microsoft.CodeAnalysis.VisualStudio.Setup.log                           10.05.2026 01:46:22  237535
dd_setup_20260510014457_192_Microsoft.VisualStudio.TextTemplating.Core.log                          10.05.2026 01:46:20    6228
dd_setup_20260510014457_191_Microsoft.VisualStudio.TextTemplating.Integration.log                   10.05.2026 01:46:20    8477
dd_setup_20260510014457_190_Microsoft.VisualStudio.TextTemplating.MSBuild.log                       10.05.2026 01:46:20    3915
dd_setup_20260510014457_189_Microsoft.VisualStudio.Debugger.Remote.DiagnosticsHub.Client.log        10.05.2026 01:46:20     610
dd_setup_20260510014457_188_Microsoft.VisualStudio.Debugger.Remote.DiagnosticsHub.Client.log        10.05.2026 01:46:20     610
dd_setup_20260510014457_187_Microsoft.VisualStudio.Debugger.Package.DiagHub.Client.log              10.05.2026 01:46:20     598
dd_setup_20260510014457_186_Microsoft.VisualStudio.PerfLib.log                                      10.05.2026 01:46:20    3231
dd_setup_20260510014457_185_Microsoft.DiaSymReader.PortablePdb.log                                  10.05.2026 01:46:20     620
dd_setup_20260510014457_184_Microsoft.VisualStudio.Debugger.Resources.log                           10.05.2026 01:46:20    2640
dd_setup_20260510014457_183_Microsoft.VisualStudio.Debugger.Concord.Resources.log                   10.05.2026 01:46:20     967
dd_setup_20260510014457_182_Microsoft.VisualStudio.Debugger.Concord.log                             10.05.2026 01:46:20    8017
dd_setup_20260510014457_181_Microsoft.VisualStudio.MinShell.Auto.Resources.log                      10.05.2026 01:46:20    1916
dd_setup_20260510014457_180_Microsoft.VisualStudio.MinShell.Auto.log                                10.05.2026 01:46:20   12419
dd_setup_20260510014457_179_Microsoft.VisualStudio.CoreDotNet.log                                   10.05.2026 01:46:20   17181
dd_setup_20260510014457_178_Microsoft.VisualStudio.UIInternal.Resources.log                         10.05.2026 01:46:20     622
dd_setup_20260510014457_177_Microsoft.VisualStudio.UIInternal.log                                   10.05.2026 01:46:20   41360
dd_setup_20260510014457_176_Microsoft.VisualStudio.UIInternal.Guide.log                             10.05.2026 01:46:19   68702
dd_setup_20260510014457_175_Microsoft.VisualStudio.MinShell.Resources.log                           10.05.2026 01:46:19    4209
dd_setup_20260510014457_174_Microsoft.VisualStudio.Devenv.Config.log                                10.05.2026 01:46:19     534
dd_setup_20260510014457_173_Microsoft.VisualStudio.MinShell.Targeted.log                            10.05.2026 01:46:19   38712
dd_setup_20260510014457_172_Microsoft.VisualStudio.Platform.Editor.log                              10.05.2026 01:46:18   28815
dd_setup_20260510014457_171_Microsoft.VisualStudio.ExtensionManager.Auto.log                        10.05.2026 01:46:18    1747
dd_setup_20260510014457_170_Microsoft.VisualStudio.ExtensionManager.log                             10.05.2026 01:46:18   14298
dd_setup_20260510014457_169_Microsoft.VisualStudio.MefHosting.log                                   10.05.2026 01:46:18    2140
dd_setup_20260510014457_168_Microsoft.VisualStudio.LanguageServer.log                               10.05.2026 01:46:18   12995
dd_setup_20260510014457_167_Microsoft.VisualStudio.Extensibility.Container.log                      10.05.2026 01:46:18   16753
dd_setup_20260510014457_166_Microsoft.VisualStudio.VsWebProtocolSelector.Msi.log                    10.05.2026 01:46:18   79288
dd_setup_20260510014457_165_Microsoft.VisualStudio.GitHubProtocolHandler.Msi.log                    10.05.2026 01:46:17   80994
dd_setup_20260510014457_164_Microsoft.VisualStudio.IdentityDependencies.log                         10.05.2026 01:46:17    3893
dd_setup_20260510014457_163_Microsoft.VisualStudio.Licensing.log                                    10.05.2026 01:46:17     982
dd_setup_20260510014457_162_Microsoft.VisualStudio.Copilot.Contracts.log                            10.05.2026 01:46:17    3649
dd_setup_20260510014457_161_Microsoft.VisualStudio.OpenTelemetry.ClientExtensions.netfx.log         10.05.2026 01:46:17    1847
dd_setup_20260510014457_160_Microsoft.VisualStudio.OpenTelemetry.Collector.netfx.log                10.05.2026 01:46:17     710
dd_setup_20260510014457_159_Microsoft.VisualStudio.MinShell.log                                     10.05.2026 01:46:17   28214
dd_setup_20260510014457_158_Microsoft.IntelliTrace.DiagnosticsHub.log                               10.05.2026 01:46:17    5256
dd_setup_20260510014457_157_Microsoft.VisualStudio.VC.MSVCDis.log                                   10.05.2026 01:46:17     536
dd_setup_20260510014457_156_Microsoft.VisualStudio.Editors.log                                      10.05.2026 01:46:17   10677
dd_setup_20260510014457_155_Microsoft.VisualStudio.AzureSDK.log                                     10.05.2026 01:46:17    3160
dd_setup_20260510014457_154_Microsoft.VisualStudio.Debugger.log                                     10.05.2026 01:46:17   27213
dd_setup_20260510014457_153_Microsoft.VisualStudio.Debugger.Remote.Resources.log                    10.05.2026 01:46:16    1445
dd_setup_20260510014457_152_Microsoft.VisualStudio.Debugger.Remote.Resources.log                    10.05.2026 01:46:16    1152
dd_setup_20260510014457_151_Microsoft.VisualStudio.Debugger.Concord.Remote.Resources.log            10.05.2026 01:46:16     616
dd_setup_20260510014457_150_Microsoft.VisualStudio.Debugger.Concord.Remote.log                      10.05.2026 01:46:16    4856
dd_setup_20260510014457_149_Microsoft.VisualStudio.Debugger.Remote.log                              10.05.2026 01:46:16   27702
dd_setup_20260510014457_148_Microsoft.VisualStudio.Debugger.Concord.Remote.Resources.log            10.05.2026 01:46:16     616
dd_setup_20260510014457_147_Microsoft.VisualStudio.Debugger.Concord.Remote.log                      10.05.2026 01:46:16    4856
dd_setup_20260510014457_146_Microsoft.VisualStudio.Debugger.Remote.log                              10.05.2026 01:46:16   27403
dd_setup_20260510014457_145_Microsoft.VisualStudio.Debugger.TargetComposition.Remote.log            10.05.2026 01:46:16    1122
dd_setup_20260510014457_144_Microsoft.VisualStudio.Debugger.TargetComposition.Remote.log            10.05.2026 01:46:16    1122
dd_setup_20260510014457_143_Microsoft.VisualStudio.Debugger.TargetComposition.log                   10.05.2026 01:46:16    1002
dd_setup_20260510014457_142_Microsoft.VisualStudio.Debugger.Managed.Resources.log                   10.05.2026 01:46:16     919
dd_setup_20260510014457_141_Microsoft.VisualStudio.Debugger.Concord.Managed.Resources.log           10.05.2026 01:46:16     316
dd_setup_20260510014457_140_Microsoft.VisualStudio.Debugger.Concord.Managed.log                     10.05.2026 01:46:16    3509
dd_setup_20260510014457_139_Microsoft.CodeAnalysis.ExpressionEvaluator.log                          10.05.2026 01:46:16   16821
dd_setup_20260510014457_138_Microsoft.DiaSymReader.log                                              10.05.2026 01:46:16     596
dd_setup_20260510014457_137_Microsoft.VisualStudio.Debugger.Managed.log                             10.05.2026 01:46:16   15781
dd_setup_20260510014457_136_Microsoft.VisualStudio.Debugger.Parallel.Resources.log                  10.05.2026 01:46:16     622
dd_setup_20260510014457_135_Microsoft.VisualStudio.Debugger.Parallel.log                            10.05.2026 01:46:16    2516
dd_setup_20260510014457_134_Microsoft.VisualStudio.Debugger.CollectionAgents.log                    10.05.2026 01:46:16     935
dd_setup_20260510014457_133_Microsoft.VisualStudio.VC.Ide.Common.Resources.log                      10.05.2026 01:46:16     807
dd_setup_20260510014457_132_Microsoft.VisualStudio.VC.Ide.Common.log                                10.05.2026 01:46:16    4383
dd_setup_20260510014457_131_Microsoft.VisualStudio.VC.Ide.Debugger.Resources.log                    10.05.2026 01:46:16     867
dd_setup_20260510014457_130_Microsoft.VisualStudio.VC.Ide.Debugger.Concord.Resources.log            10.05.2026 01:46:16     819
dd_setup_20260510014457_129_Microsoft.VisualStudio.VC.Ide.Debugger.Concord.log                      10.05.2026 01:46:16    1457
dd_setup_20260510014457_128_Microsoft.VisualStudio.VC.Ide.Debugger.log                              10.05.2026 01:46:16    8652
dd_setup_20260510014457_127_Microsoft.WebTools.DotNet.Core.ItemTemplates.log                        10.05.2026 01:46:15    2798
dd_setup_20260510014457_126_Microsoft.WebTools.Shared.log                                           10.05.2026 01:46:15  144413
dd_setup_20260510014457_125_Microsoft.VisualStudio.Web.Azure.Common.log                             10.05.2026 01:46:14    3621
dd_setup_20260510014457_124_Microsoft.VisualStudio.Debugger.AzureAttach.log                         10.05.2026 01:46:14    1039
dd_setup_20260510014457_123_Microsoft.VisualStudio.Debugger.VSCodeDebuggerHost.log                  10.05.2026 01:46:14    7815
dd_setup_20260510014457_122_Microsoft.VisualStudio.Debugger.BrokeredServices.log                    10.05.2026 01:46:14    6225
dd_setup_20260510014457_121_Microsoft.VisualStudio.VC.Ide.Base.Resources.log                        10.05.2026 01:46:14    1509
dd_setup_20260510014457_120_Microsoft.VisualStudio.VC.Llvm.Base.log                                 10.05.2026 01:46:14   28353
dd_setup_20260510014457_119_Microsoft.VisualStudio.VC.Ide.LanguageService.Resources.log             10.05.2026 01:46:14   16212
dd_setup_20260510014457_118_Microsoft.VisualStudio.VC.Ide.Core.VCProjectEngine.Resources.log        10.05.2026 01:46:14     503
dd_setup_20260510014457_117_Microsoft.VisualStudio.VC.Ide.Core.VCProjectEngine.log                  10.05.2026 01:46:14     626
dd_setup_20260510014457_116_Microsoft.VisualStudio.VC.Ide.ProjectSystem.Resources.log               10.05.2026 01:46:14    1758
dd_setup_20260510014457_115_Microsoft.VisualStudio.VC.Ide.ProjectSystem.log                         10.05.2026 01:46:14    6276
dd_setup_20260510014457_114_Microsoft.VisualStudio.VisualC.Utilities.Resources.log                  10.05.2026 01:46:13     309
dd_setup_20260510014457_113_Microsoft.VisualStudio.VisualC.Utilities.log                            10.05.2026 01:46:13     949
dd_setup_20260510014457_112_Microsoft.VisualStudio.VC.Ide.Core.log                                  10.05.2026 01:46:13    2477
dd_setup_20260510014457_111_Microsoft.VisualStudio.VC.Ide.LanguageService.Dependencies.log          10.05.2026 01:46:13     981
dd_setup_20260510014457_110_Microsoft.VisualStudio.VC.Ide.ResourceEditor.Resources.log              10.05.2026 01:46:13    1361
dd_setup_20260510014457_109_Microsoft.VisualStudio.VC.Ide.ResourceEditor.log                        10.05.2026 01:46:13    4472
dd_setup_20260510014457_108_Microsoft.VisualStudio.VC.Ide.VCPkgDatabase.log                         10.05.2026 01:46:13     616
dd_setup_20260510014457_107_Microsoft.VisualStudio.VC.Copilot.Setup.log                             10.05.2026 01:46:13    1697
dd_setup_20260510014457_106_Microsoft.VisualStudio.VC.Ide.LanguageService.log                       10.05.2026 01:46:13   18999
dd_setup_20260510014457_105_Microsoft.VisualStudio.VC.Ide.Base.log                                  10.05.2026 01:46:13   42786
dd_setup_20260510014457_104_Microsoft.VisualStudio.VC.Ide.Dskx.Resources.log                        10.05.2026 01:46:13     789
dd_setup_20260510014457_103_Microsoft.VisualStudio.VC.Ide.Dskx.log                                  10.05.2026 01:46:13    1986
dd_setup_20260510014457_102_Microsoft.VisualStudio.VC.Ide.WinXPlus.log                              10.05.2026 01:46:13    7267
dd_setup_20260510014457_101_Microsoft.VisualStudio.Debugger.Script.Remote.Resources.log             10.05.2026 01:46:13     620
dd_setup_20260510014457_100_Microsoft.VisualStudio.Debugger.Script.Remote.Resources.log             10.05.2026 01:46:13     620
dd_setup_20260510014457_099_Microsoft.VisualStudio.Debugger.Script.Remote.log                       10.05.2026 01:46:13     883
dd_setup_20260510014457_098_Microsoft.VisualStudio.Debugger.Script.Remote.log                       10.05.2026 01:46:13     887
dd_setup_20260510014457_097_Microsoft.VisualStudio.Debugger.Script.Resources.log                    10.05.2026 01:46:13     608
dd_setup_20260510014457_096_Microsoft.VisualStudio.Debugger.Script.log                              10.05.2026 01:46:13    1202
dd_setup_20260510014457_095_Microsoft.VisualStudio.Debugger.Script.Msi.log                          10.05.2026 01:46:13  171528
dd_setup_20260510014457_094_Microsoft.VisualStudio.VC.Ide.x64.log                                   10.05.2026 01:46:12     568
dd_setup_20260510014457_093_Microsoft.VisualStudio.Connected.Resources.log                          10.05.2026 01:46:12     301
dd_setup_20260510014457_092_Microsoft.VisualStudio.Connected.Auto.Resources.log                     10.05.2026 01:46:12     654
dd_setup_20260510014457_091_Microsoft.VisualStudio.Connected.Auto.log                               10.05.2026 01:46:12    1400
dd_setup_20260510014457_090_SQLitePCLRaw.Targeted.log                                               10.05.2026 01:46:12     630
dd_setup_20260510014457_089_SQLitePCLRaw.log                                                        10.05.2026 01:46:12    1497
dd_setup_20260510014457_088_Microsoft.Developer.IdentityServiceGS.log                               10.05.2026 01:46:12    5997
dd_setup_20260510014457_087_Microsoft.VisualStudio.Identity.log                                     10.05.2026 01:46:12  173983
dd_setup_20260510014457_086_Microsoft.VisualStudio.Connected.log                                    10.05.2026 01:46:11    8913
dd_setup_20260510014457_085_Microsoft.VisualStudio.Platform.NavigateTo.log                          10.05.2026 01:46:11    2023
dd_setup_20260510014457_084_Microsoft.VisualStudio.CoreEditor.UserProfiles.log                      10.05.2026 01:46:11    2044
dd_setup_20260510014457_083_Microsoft.VisualStudio.CoreEditor.log                                   10.05.2026 01:46:10    9461
dd_setup_20260510014457_082_Microsoft.VisualStudio.ErrorList.log                                    10.05.2026 01:46:10    6014
dd_setup_20260510014457_081_Microsoft.VisualStudio.Finalizer.log                                    10.05.2026 01:46:10    4239
dd_setup_20260510014457_080_Microsoft.VisualStudio.Log.Resources.log                                10.05.2026 01:46:10     540
dd_setup_20260510014457_079_Microsoft.VisualStudio.Log.Targeted.log                                 10.05.2026 01:46:10     608
dd_setup_20260510014457_078_Microsoft.VisualStudio.Log.log                                          10.05.2026 01:46:10    4256
dd_setup_20260510014457_077_Microsoft.VisualStudio.NgenRunner.log                                   10.05.2026 01:46:10     783
dd_setup_20260510014457_076_Microsoft.VisualStudio.MinShell.Interop.log                             10.05.2026 01:46:10   14819
dd_setup_20260510014457_075_Microsoft.VisualStudio.MinShell.Msi.Resources.log                       10.05.2026 01:46:10   75376
dd_setup_20260510014457_074_Microsoft.VisualStudio.MinShell.Shared.Msi.log                          10.05.2026 01:46:10   88526
dd_setup_20260510014457_073_Microsoft.VisualStudio.MinShell.Msi.log                                 10.05.2026 01:46:10   70328
dd_setup_20260510014457_072_Microsoft.VisualStudio.FileHandler.Msi.log                              10.05.2026 01:46:10  181502
dd_setup_20260510014457_071_Microsoft.VisualStudio.FileHandler.Msi.log                              10.05.2026 01:46:09  121348
dd_setup_20260510014457_070_Microsoft.VisualStudio.OpenFolder.VSIX.log                              10.05.2026 01:46:09   32787
dd_setup_20260510014457_069_Microsoft.ServiceHub.Managed.log                                        10.05.2026 01:46:09   16847
dd_setup_20260510014457_068_Microsoft.ServiceHub.Node.log                                           10.05.2026 01:46:09    2029
dd_setup_20260510014457_067_Microsoft.VisualStudio.Platform.Markdown.log                            10.05.2026 01:46:09   12439
dd_setup_20260510014457_066_Microsoft.VisualStudio.TextMateGrammars.log                             10.05.2026 01:46:09  116088
dd_setup_20260510014457_065_Microsoft.VisualStudio.GraphProvider.Auto.log                           10.05.2026 01:46:08    2356
dd_setup_20260510014457_064_Microsoft.VisualStudio.GraphProvider.log                                10.05.2026 01:46:08    3902
dd_setup_20260510014457_063_Microsoft.VisualStudio.GraphModel.log                                   10.05.2026 01:46:08     921
dd_setup_20260510014457_062_Microsoft.VisualStudio.PerformanceProvider.log                          10.05.2026 01:46:08     660
dd_setup_20260510014457_061_Microsoft.VisualStudio.VirtualTree.log                                  10.05.2026 01:46:07     628
dd_setup_20260510014457_060_Microsoft.VisualStudio.ScriptedHost.Targeted.log                        10.05.2026 01:46:07     580
dd_setup_20260510014457_059_Microsoft.VisualStudio.ScriptedHost.log                                 10.05.2026 01:46:07    1752
dd_setup_20260510014457_058_Microsoft.DiagnosticsHub.Collection.Service.log                         10.05.2026 01:46:07  107476
dd_setup_20260510014457_057_Microsoft.DiagnosticsHub.Collection.log                                 10.05.2026 01:46:07    5373
dd_setup_20260510014457_056_Microsoft.DiagnosticsHub.Runtime.log                                    10.05.2026 01:46:07   36386
dd_setup_20260510014457_055_Microsoft.VisualStudio.MinShell.Interop.Shared.Msi.log                  10.05.2026 01:46:07  447812
dd_setup_20260510014457_054_Microsoft.VisualStudio.MinShell.Interop.Msi.log                         10.05.2026 01:46:06 1807532
dd_setup_20260510014457_053_Microsoft.VisualStudio.Community.Shared.Msi.log                         10.05.2026 01:46:05  444184
dd_setup_20260510014457_052_Microsoft.VisualStudio.Community.Msi.log                                10.05.2026 01:46:04  251254
dd_setup_20260510014457_051_Microsoft.VisualStudio.Community.Msi.Resources.log                      10.05.2026 01:46:04   73426
dd_setup_20260510014457_050_Microsoft.VisualStudio.Community.ProductArch.Neutral.log                10.05.2026 01:46:03   45426
dd_setup_20260510014457_049_Microsoft.VisualStudio.Platform.CallHierarchy.log                       10.05.2026 01:46:03    6886
dd_setup_20260510014457_048_Microsoft.MSHtml.log                                                    10.05.2026 01:46:03     582
dd_setup_20260510014457_047_Microsoft.VisualStudio.Diagnostics.AspNetHelper.log                     10.05.2026 01:46:03     306
dd_setup_20260510014457_046_Microsoft.VisualStudio.WebSiteProject.DTE.log                           10.05.2026 01:46:03    1140
dd_setup_20260510014457_045_Microsoft.VisualStudio.Community.ProductArch.Resources.Neutral.log      10.05.2026 01:46:03   16945
dd_setup_20260510014457_044_Microsoft.VisualStudio.Community.ProductArch.Resources.NeutralExtra.log 10.05.2026 01:46:02   32857
dd_setup_20260510014457_043_Microsoft.VisualStudio.Community.ProductArch.Resources.Targeted.log     10.05.2026 01:46:02    3491
dd_setup_20260510014457_042_Microsoft.VisualStudio.Community.CSharp.Resources.Neutral.log           10.05.2026 01:46:02   20273
dd_setup_20260510014457_041_Microsoft.VisualStudio.Community.CSharp.Resources.Targeted.log          10.05.2026 01:46:02     550
dd_setup_20260510014457_040_Microsoft.VisualStudio.Community.VB.Resources.Neutral.log               10.05.2026 01:46:02  111144
dd_setup_20260510014457_039_Microsoft.VisualStudio.Community.VB.Resources.Targeted.log              10.05.2026 01:46:01     998
dd_setup_20260510014457_038_Microsoft.IntelliTrace.CollectorCab.log                                 10.05.2026 01:46:01     971
dd_setup_20260510014457_037_Microsoft.VisualStudio.Community.ProductArch.NeutralExtra.log           10.05.2026 01:46:01    4968
dd_setup_20260510014457_036_Microsoft.VisualStudio.Community.ProductArch.Targeted.log               10.05.2026 01:46:01   10392
dd_setup_20260510014457_035_Microsoft.VisualStudio.Community.ProductArch.TargetedExtra.log          10.05.2026 01:46:01    1682
dd_setup_20260510014457_034_Microsoft.VisualStudio.Community.CSharp.Neutral.log                     10.05.2026 01:46:01    7760
dd_setup_20260510014457_033_Microsoft.VisualStudio.Community.CSharp.Targeted.log                    10.05.2026 01:46:00    1660
dd_setup_20260510014457_032_Microsoft.VisualStudio.Community.VB.Neutral.log                         10.05.2026 01:46:00    3742
dd_setup_20260510014457_031_Microsoft.VisualStudio.Community.VB.Targeted.log                        10.05.2026 01:46:00    1177
dd_setup_20260510014457_030_Microsoft.VisualStudio.Community.x64.log                                10.05.2026 01:46:00    1441
dd_setup_20260510014457_029_Microsoft.VisualStudio.Community.x86.log                                10.05.2026 01:46:00    1475
dd_setup_20260510014457_028_Microsoft.VisualStudio.ProjectSystem.log                                10.05.2026 01:46:00   17450
dd_setup_20260510014457_027_Microsoft.VisualStudio.ProjectSystem.Query.log                          10.05.2026 01:46:00   10995
dd_setup_20260510014457_026_Microsoft.VisualStudio.LiveShareApi.log                                 10.05.2026 01:46:00     648
dd_setup_20260510014457_025_Microsoft.VisualStudio.ProjectSystem.Full.log                           10.05.2026 01:46:00     584
dd_setup_20260510014457_024_Microsoft.VisualStudio.ClientDiagnostics.Resources.log                  10.05.2026 01:46:00     712
dd_setup_20260510014457_023_Microsoft.VisualStudio.ClientDiagnostics.Targeted.log                   10.05.2026 01:46:00     957
dd_setup_20260510014457_022_Microsoft.VisualStudio.ClientDiagnostics.log                            10.05.2026 01:46:00    4434
dd_setup_20260510014457_021_Microsoft.VisualStudio.AppResponsiveness.Resources.log                  10.05.2026 01:46:00    1530
dd_setup_20260510014457_020_Microsoft.VisualStudio.AppResponsiveness.Targeted.log                   10.05.2026 01:46:00     692
dd_setup_20260510014457_019_Microsoft.VisualStudio.AppResponsiveness.log                            10.05.2026 01:46:00   18193
dd_setup_20260510014457_018_Microsoft.VisualStudio.TestTools.TeamFoundationClient.log               10.05.2026 01:46:00   12338
dd_setup_20260510014457_017_Microsoft.VisualStudio.CodeSense.Community.log                          10.05.2026 01:45:59    2367
dd_setup_20260510014457_016_Microsoft.VisualStudio.VC.Ide.MDD.log                                   10.05.2026 01:45:59    7940
dd_setup_20260510014457_015_Microsoft.VisualStudio.VC.Items.Pro.log                                 10.05.2026 01:45:59    1674
dd_setup_20260510014457_014_Microsoft.VisualStudio.VC.Templates.General.Resources.log               10.05.2026 01:45:59    5072
dd_setup_20260510014457_013_Microsoft.VisualStudio.VC.Templates.General.log                         10.05.2026 01:45:59   16521
dd_setup_20260510014457_012_Microsoft.VisualStudio.VC.Ide.Pro.Resources.log                         10.05.2026 01:45:59    5808
dd_setup_20260510014457_011_Microsoft.VisualStudio.VC.Ide.Pro.log                                   10.05.2026 01:45:59     292
dd_setup_20260510014457_010_Microsoft.VisualStudio.VC.Templates.Desktop.log                         10.05.2026 01:45:59    6900
dd_setup_20260510014457_009_Microsoft.VisualStudio.VC.Templates.UnitTest.Resources.log              10.05.2026 01:45:59    1964
dd_setup_20260510014457_008_Microsoft.VisualStudio.VC.Templates.UnitTest.log                        10.05.2026 01:45:59    3140
dd_setup_20260510014457_007_Microsoft.VisualStudio.TestTools.TestPlatform.IDE.log                   10.05.2026 01:45:59  372937
dd_setup_20260510014457_006_Microsoft.VisualStudio.TestTools.TestWIExtension.log                    10.05.2026 01:45:56    1584
dd_setup_20260510014457_005_Microsoft.VisualStudio.VC.Ide.Linux.ConnectionManager.Resources.log     10.05.2026 01:45:56    4237
dd_setup_20260510014457_004_Microsoft.VisualStudio.VC.Ide.Linux.Shared.Resources.log                10.05.2026 01:45:56     648
dd_setup_20260510014457_003_Microsoft.VisualStudio.VC.Ide.Linux.Shared.log                          10.05.2026 01:45:55     622
dd_setup_20260510014457_002_Microsoft.VisualStudio.VC.Ide.Linux.ConnectionManager.log               10.05.2026 01:45:55    6595
dd_setup_20260510014457_001_Win11SDK_10.0.22621.log                                                 10.05.2026 01:45:55     730
dd_setup_20260510014457_errors.log                                                                  10.05.2026 01:44:57       0
dd_setup_20260510014454.log                                                                         10.05.2026 01:44:56    7846
dd_setup_20260510014454_errors.log                                                                  10.05.2026 01:44:54       0
dd_installer_elevated_20260510014437.log                                                            10.05.2026 01:44:50 3343680
dd_setup_20260510014438.log                                                                         10.05.2026 01:44:50 3334031
dd_setup_20260510014438_215_Microsoft.VisualStudio.VC.Icons.log                                     10.05.2026 01:44:49     528
dd_setup_20260510014438_214_Microsoft.VisualStudio.NuGet.BuildTools.log                             10.05.2026 01:44:49   79719
dd_setup_20260510014438_213_Microsoft.Build.log                                                     10.05.2026 01:44:49   83069
dd_setup_20260510014438_212_Microsoft.VisualStudio.NativeImageSupport.log                           10.05.2026 01:44:49     747
dd_setup_20260510014438_211_Microsoft.CodeAnalysis.Compilers.log                                    10.05.2026 01:44:49   35269
dd_setup_20260510014438_210_Microsoft.NuGet.Build.Tasks.Setup.log                                   10.05.2026 01:44:49    2476
dd_setup_20260510014438_209_Microsoft.PythonTools.BuildCore.Vsix.log                                10.05.2026 01:44:49    5683
dd_setup_20260510014438_208_Microsoft.Build.Dependencies.log                                        10.05.2026 01:44:49  156800
dd_setup_20260510014438_207_Microsoft.VisualStudio.Net.Eula.Resources.log                           10.05.2026 01:44:49     558
dd_setup_20260510014438_206_Microsoft.VisualStudio.BuildTools.Resources.log                         10.05.2026 01:44:49     576
dd_setup_20260510014438_205_Microsoft.VisualStudio.VC.DevCmd.Resources.log                          10.05.2026 01:44:49     608
dd_setup_20260510014438_204_Microsoft.VisualStudio.VC.DevCmd.log                                    10.05.2026 01:44:49    3666
dd_setup_20260510014438_203_Microsoft.VisualStudio.VsDevCmd.Core.DotNet.log                         10.05.2026 01:44:49     560
dd_setup_20260510014438_202_Microsoft.VisualStudio.VsDevCmd.Core.WinSdk.log                         10.05.2026 01:44:49     560
dd_setup_20260510014438_201_Microsoft.VisualStudio.VsDevCmd.Ext.NetFxSdk.log                        10.05.2026 01:44:49     562
dd_setup_20260510014438_200_Microsoft.VisualStudio.Setup.Configuration.Interop.log                  10.05.2026 01:44:49     652
dd_setup_20260510014438_199_Microsoft.VisualStudio.VC.MSBuild.v170.Base.Resources.log               10.05.2026 01:44:49   14132
dd_setup_20260510014438_198_Microsoft.VisualStudio.VC.MSBuild.v170.Base.log                         10.05.2026 01:44:49   29762
dd_setup_20260510014438_197_Microsoft.VisualStudio.VC.MSBuild.v170.ARM.log                          10.05.2026 01:44:48    1469
dd_setup_20260510014438_196_Microsoft.VisualStudio.VC.MSBuild.v170.ARM.v143.log                     10.05.2026 01:44:48     961
dd_setup_20260510014438_195_Microsoft.VisualStudio.VC.MSBuild.v170.X64.log                          10.05.2026 01:44:48    1469
dd_setup_20260510014438_194_Microsoft.VisualStudio.VC.MSBuild.v170.X64.v143.log                     10.05.2026 01:44:48     961
dd_setup_20260510014438_193_Microsoft.VisualStudio.VC.MSBuild.v170.X86.log                          10.05.2026 01:44:48    1485
dd_setup_20260510014438_192_Microsoft.VisualStudio.VC.MSBuild.v170.x86.v143.log                     10.05.2026 01:44:48     969
dd_setup_20260510014438_191_Microsoft.VS.VC.vcvars.x64.Shortcuts.log                                10.05.2026 01:44:48     295
dd_setup_20260510014438_190_Microsoft.VS.VC.vcvars.x86.Shortcuts.log                                10.05.2026 01:44:48     295
dd_setup_20260510014438_189_Microsoft.VisualStudio.VC.vcvars.log                                    10.05.2026 01:44:48     825
dd_setup_20260510014438_188_Microsoft.VisualCpp.Servicing.Redist.log                                10.05.2026 01:44:48    1515
dd_setup_20260510014438_187_Microsoft.VisualCpp.Tools.Common.Utils.Resources.log                    10.05.2026 01:44:48     785
dd_setup_20260510014438_186_Microsoft.VisualCpp.Tools.Common.Utils.log                              10.05.2026 01:44:48    1851
dd_setup_20260510014438_185_Microsoft.VisualStudio.TestTools.TestPlatform.V1.CPP.log                10.05.2026 01:44:48     700
dd_setup_20260510014438_184_Microsoft.VisualStudio.VC.UnitTest.Desktop.Build.Core.log               10.05.2026 01:44:48    5110
dd_setup_20260510014438_183_Microsoft.VisualStudio.TestTools.TestPlatform.V2.CLI.log                10.05.2026 01:44:48  146033
dd_setup_20260510014438_182_Microsoft.VisualStudio.TestTools.TestPlatform.V1.CLI.log                10.05.2026 01:44:48    2654
dd_setup_20260510014438_181_Microsoft.VisualStudio.InstrumentationEngine.log                        10.05.2026 01:44:48    1065
dd_setup_20260510014438_180_Microsoft.VisualStudio.TestTools.DynamicCodeCoverage.log                10.05.2026 01:44:48   16382
dd_setup_20260510014438_179_Microsoft.VisualStudio.TextTemplating.Integration.Resources.log         10.05.2026 01:44:48     594
dd_setup_20260510014438_178_Microsoft.CodeAnalysis.VisualStudio.Setup.log                           10.05.2026 01:44:48  237535
dd_setup_20260510014438_177_Microsoft.VisualStudio.TextTemplating.Core.log                          10.05.2026 01:44:48    6228
dd_setup_20260510014438_176_Microsoft.VisualStudio.TextTemplating.Integration.log                   10.05.2026 01:44:48    8477
dd_setup_20260510014438_175_Microsoft.VisualStudio.TextTemplating.MSBuild.log                       10.05.2026 01:44:48    3915
dd_setup_20260510014438_174_Microsoft.VisualStudio.Debugger.Remote.DiagnosticsHub.Client.log        10.05.2026 01:44:48     610
dd_setup_20260510014438_173_Microsoft.VisualStudio.Debugger.Remote.DiagnosticsHub.Client.log        10.05.2026 01:44:48     610
dd_setup_20260510014438_172_Microsoft.VisualStudio.Debugger.Package.DiagHub.Client.log              10.05.2026 01:44:48     598
dd_setup_20260510014438_171_Microsoft.VisualStudio.PerfLib.log                                      10.05.2026 01:44:48    3231
dd_setup_20260510014438_170_Microsoft.DiaSymReader.PortablePdb.log                                  10.05.2026 01:44:48     620
dd_setup_20260510014438_169_Microsoft.VisualStudio.Debugger.Resources.log                           10.05.2026 01:44:48    2640
dd_setup_20260510014438_168_Microsoft.VisualStudio.Debugger.Concord.Resources.log                   10.05.2026 01:44:48     967
dd_setup_20260510014438_167_Microsoft.VisualStudio.Debugger.Concord.log                             10.05.2026 01:44:48    8017
dd_setup_20260510014438_166_Microsoft.VisualStudio.MinShell.Auto.Resources.log                      10.05.2026 01:44:48    1916
dd_setup_20260510014438_165_Microsoft.VisualStudio.MinShell.Auto.log                                10.05.2026 01:44:48   12419
dd_setup_20260510014438_164_Microsoft.VisualStudio.CoreDotNet.log                                   10.05.2026 01:44:48   17181
dd_setup_20260510014438_163_Microsoft.VisualStudio.UIInternal.Resources.log                         10.05.2026 01:44:48     622
dd_setup_20260510014438_162_Microsoft.VisualStudio.UIInternal.log                                   10.05.2026 01:44:48   41360
dd_setup_20260510014438_161_Microsoft.VisualStudio.UIInternal.Guide.log                             10.05.2026 01:44:48   68702
dd_setup_20260510014438_160_Microsoft.VisualStudio.MinShell.Resources.log                           10.05.2026 01:44:47    4209
dd_setup_20260510014438_159_Microsoft.VisualStudio.Devenv.Config.log                                10.05.2026 01:44:47     534
dd_setup_20260510014438_158_Microsoft.VisualStudio.MinShell.Targeted.log                            10.05.2026 01:44:47   38712
dd_setup_20260510014438_157_Microsoft.VisualStudio.Platform.Editor.log                              10.05.2026 01:44:47   28815
dd_setup_20260510014438_156_Microsoft.VisualStudio.ExtensionManager.Auto.log                        10.05.2026 01:44:47    1747
dd_setup_20260510014438_155_Microsoft.VisualStudio.ExtensionManager.log                             10.05.2026 01:44:47   14298
dd_setup_20260510014438_154_Microsoft.VisualStudio.MefHosting.log                                   10.05.2026 01:44:47    2140
dd_setup_20260510014438_153_Microsoft.VisualStudio.LanguageServer.log                               10.05.2026 01:44:47   12995
dd_setup_20260510014438_152_Microsoft.VisualStudio.Extensibility.Container.log                      10.05.2026 01:44:47   16753
dd_setup_20260510014438_151_Microsoft.VisualStudio.IdentityDependencies.log                         10.05.2026 01:44:47    3893
dd_setup_20260510014438_150_Microsoft.VisualStudio.Licensing.log                                    10.05.2026 01:44:47     982
dd_setup_20260510014438_149_Microsoft.VisualStudio.Copilot.Contracts.log                            10.05.2026 01:44:47    3649
dd_setup_20260510014438_148_Microsoft.VisualStudio.OpenTelemetry.ClientExtensions.netfx.log         10.05.2026 01:44:47    1847
dd_setup_20260510014438_147_Microsoft.VisualStudio.OpenTelemetry.Collector.netfx.log                10.05.2026 01:44:47     710
dd_setup_20260510014438_146_Microsoft.VisualStudio.MinShell.log                                     10.05.2026 01:44:47   28214
dd_setup_20260510014438_145_Microsoft.IntelliTrace.DiagnosticsHub.log                               10.05.2026 01:44:47    5256
dd_setup_20260510014438_144_Microsoft.VisualStudio.VC.MSVCDis.log                                   10.05.2026 01:44:47     536
dd_setup_20260510014438_143_Microsoft.VisualStudio.Editors.log                                      10.05.2026 01:44:47   10677
dd_setup_20260510014438_142_Microsoft.VisualStudio.AzureSDK.log                                     10.05.2026 01:44:47    3160
dd_setup_20260510014438_141_Microsoft.VisualStudio.Debugger.log                                     10.05.2026 01:44:47   27213
dd_setup_20260510014438_140_Microsoft.VisualStudio.Debugger.Remote.Resources.log                    10.05.2026 01:44:47    1445
dd_setup_20260510014438_139_Microsoft.VisualStudio.Debugger.Remote.Resources.log                    10.05.2026 01:44:47    1152
dd_setup_20260510014438_138_Microsoft.VisualStudio.Debugger.Concord.Remote.Resources.log            10.05.2026 01:44:47     616
dd_setup_20260510014438_137_Microsoft.VisualStudio.Debugger.Concord.Remote.log                      10.05.2026 01:44:47    4856
dd_setup_20260510014438_136_Microsoft.VisualStudio.Debugger.Remote.log                              10.05.2026 01:44:47   27702
dd_setup_20260510014438_135_Microsoft.VisualStudio.Debugger.Concord.Remote.Resources.log            10.05.2026 01:44:47     616
dd_setup_20260510014438_134_Microsoft.VisualStudio.Debugger.Concord.Remote.log                      10.05.2026 01:44:47    4856
dd_setup_20260510014438_133_Microsoft.VisualStudio.Debugger.Remote.log                              10.05.2026 01:44:47   27403
dd_setup_20260510014438_132_Microsoft.VisualStudio.Debugger.TargetComposition.Remote.log            10.05.2026 01:44:47    1122
dd_setup_20260510014438_131_Microsoft.VisualStudio.Debugger.TargetComposition.Remote.log            10.05.2026 01:44:47    1122
dd_setup_20260510014438_130_Microsoft.VisualStudio.Debugger.TargetComposition.log                   10.05.2026 01:44:47    1002
dd_setup_20260510014438_129_Microsoft.VisualStudio.Debugger.Managed.Resources.log                   10.05.2026 01:44:47     919
dd_setup_20260510014438_128_Microsoft.VisualStudio.Debugger.Concord.Managed.Resources.log           10.05.2026 01:44:47     316
dd_setup_20260510014438_127_Microsoft.VisualStudio.Debugger.Concord.Managed.log                     10.05.2026 01:44:47    3509
dd_setup_20260510014438_126_Microsoft.CodeAnalysis.ExpressionEvaluator.log                          10.05.2026 01:44:47   16821
dd_setup_20260510014438_125_Microsoft.DiaSymReader.log                                              10.05.2026 01:44:47     596
dd_setup_20260510014438_124_Microsoft.VisualStudio.Debugger.Managed.log                             10.05.2026 01:44:47   15781
dd_setup_20260510014438_123_Microsoft.VisualStudio.Debugger.Parallel.Resources.log                  10.05.2026 01:44:47     622
dd_setup_20260510014438_122_Microsoft.VisualStudio.Debugger.Parallel.log                            10.05.2026 01:44:47    2516
dd_setup_20260510014438_121_Microsoft.VisualStudio.Debugger.CollectionAgents.log                    10.05.2026 01:44:47     935
dd_setup_20260510014438_120_Microsoft.VisualStudio.VC.Ide.Common.Resources.log                      10.05.2026 01:44:47     807
dd_setup_20260510014438_119_Microsoft.VisualStudio.VC.Ide.Common.log                                10.05.2026 01:44:47    4383
dd_setup_20260510014438_118_Microsoft.VisualStudio.VC.Ide.Debugger.Resources.log                    10.05.2026 01:44:47     867
dd_setup_20260510014438_117_Microsoft.VisualStudio.VC.Ide.Debugger.Concord.Resources.log            10.05.2026 01:44:46     819
dd_setup_20260510014438_116_Microsoft.VisualStudio.VC.Ide.Debugger.Concord.log                      10.05.2026 01:44:46    1457
dd_setup_20260510014438_115_Microsoft.VisualStudio.VC.Ide.Debugger.log                              10.05.2026 01:44:46    8652
dd_setup_20260510014438_114_Microsoft.WebTools.DotNet.Core.ItemTemplates.log                        10.05.2026 01:44:46    2798
dd_setup_20260510014438_113_Microsoft.WebTools.Shared.log                                           10.05.2026 01:44:46  144413
dd_setup_20260510014438_112_Microsoft.VisualStudio.Web.Azure.Common.log                             10.05.2026 01:44:46    3621
dd_setup_20260510014438_111_Microsoft.VisualStudio.Debugger.AzureAttach.log                         10.05.2026 01:44:46    1039
dd_setup_20260510014438_110_Microsoft.VisualStudio.Debugger.VSCodeDebuggerHost.log                  10.05.2026 01:44:46    7815
dd_setup_20260510014438_109_Microsoft.VisualStudio.Debugger.BrokeredServices.log                    10.05.2026 01:44:46    6225
dd_setup_20260510014438_108_Microsoft.VisualStudio.VC.Ide.Base.Resources.log                        10.05.2026 01:44:46    1509
dd_setup_20260510014438_107_Microsoft.VisualStudio.VC.Llvm.Base.log                                 10.05.2026 01:44:46   28353
dd_setup_20260510014438_106_Microsoft.VisualStudio.VC.Ide.LanguageService.Resources.log             10.05.2026 01:44:46   16212
dd_setup_20260510014438_105_Microsoft.VisualStudio.VC.Ide.Core.VCProjectEngine.Resources.log        10.05.2026 01:44:46     503
dd_setup_20260510014438_104_Microsoft.VisualStudio.VC.Ide.Core.VCProjectEngine.log                  10.05.2026 01:44:46     626
dd_setup_20260510014438_103_Microsoft.VisualStudio.VC.Ide.ProjectSystem.Resources.log               10.05.2026 01:44:46    1758
dd_setup_20260510014438_102_Microsoft.VisualStudio.VC.Ide.ProjectSystem.log                         10.05.2026 01:44:46    6276
dd_setup_20260510014438_101_Microsoft.VisualStudio.VisualC.Utilities.Resources.log                  10.05.2026 01:44:46     309
dd_setup_20260510014438_100_Microsoft.VisualStudio.VisualC.Utilities.log                            10.05.2026 01:44:46     949
dd_setup_20260510014438_099_Microsoft.VisualStudio.VC.Ide.Core.log                                  10.05.2026 01:44:46    2477
dd_setup_20260510014438_098_Microsoft.VisualStudio.VC.Ide.LanguageService.Dependencies.log          10.05.2026 01:44:46     981
dd_setup_20260510014438_097_Microsoft.VisualStudio.VC.Ide.ResourceEditor.Resources.log              10.05.2026 01:44:46    1361
dd_setup_20260510014438_096_Microsoft.VisualStudio.VC.Ide.ResourceEditor.log                        10.05.2026 01:44:46    4472
dd_setup_20260510014438_095_Microsoft.VisualStudio.VC.Ide.VCPkgDatabase.log                         10.05.2026 01:44:46     616
dd_setup_20260510014438_094_Microsoft.VisualStudio.VC.Copilot.Setup.log                             10.05.2026 01:44:46    1697
dd_setup_20260510014438_093_Microsoft.VisualStudio.VC.Ide.LanguageService.log                       10.05.2026 01:44:46   18999
dd_setup_20260510014438_092_Microsoft.VisualStudio.VC.Ide.Base.log                                  10.05.2026 01:44:46   42786
dd_setup_20260510014438_091_Microsoft.VisualStudio.VC.Ide.Dskx.Resources.log                        10.05.2026 01:44:46     789
dd_setup_20260510014438_090_Microsoft.VisualStudio.VC.Ide.Dskx.log                                  10.05.2026 01:44:46    1986
dd_setup_20260510014438_089_Microsoft.VisualStudio.VC.Ide.WinXPlus.log                              10.05.2026 01:44:46    7267
dd_setup_20260510014438_088_Microsoft.VisualStudio.Debugger.Script.Remote.Resources.log             10.05.2026 01:44:46     620
dd_setup_20260510014438_087_Microsoft.VisualStudio.Debugger.Script.Remote.Resources.log             10.05.2026 01:44:46     620
dd_setup_20260510014438_086_Microsoft.VisualStudio.Debugger.Script.Remote.log                       10.05.2026 01:44:46     883
dd_setup_20260510014438_085_Microsoft.VisualStudio.Debugger.Script.Remote.log                       10.05.2026 01:44:46     887
dd_setup_20260510014438_084_Microsoft.VisualStudio.Debugger.Script.Resources.log                    10.05.2026 01:44:46     608
dd_setup_20260510014438_083_Microsoft.VisualStudio.Debugger.Script.log                              10.05.2026 01:44:46    1202
dd_setup_20260510014438_082_Microsoft.VisualStudio.VC.Ide.x64.log                                   10.05.2026 01:44:46     568
dd_setup_20260510014438_081_Microsoft.VisualStudio.Connected.Resources.log                          10.05.2026 01:44:46     301
dd_setup_20260510014438_080_Microsoft.VisualStudio.Connected.Auto.Resources.log                     10.05.2026 01:44:46     654
dd_setup_20260510014438_079_Microsoft.VisualStudio.Connected.Auto.log                               10.05.2026 01:44:46    1400
dd_setup_20260510014438_078_SQLitePCLRaw.Targeted.log                                               10.05.2026 01:44:46     630
dd_setup_20260510014438_077_SQLitePCLRaw.log                                                        10.05.2026 01:44:46    1497
dd_setup_20260510014438_076_Microsoft.Developer.IdentityServiceGS.log                               10.05.2026 01:44:46    5997
dd_setup_20260510014438_075_Microsoft.VisualStudio.Identity.log                                     10.05.2026 01:44:46  173983
dd_setup_20260510014438_074_Microsoft.VisualStudio.Connected.log                                    10.05.2026 01:44:45    8913
dd_setup_20260510014438_073_Microsoft.VisualStudio.Platform.NavigateTo.log                          10.05.2026 01:44:45    2023
dd_setup_20260510014438_072_Microsoft.VisualStudio.CoreEditor.UserProfiles.log                      10.05.2026 01:44:45    2044
dd_setup_20260510014438_071_Microsoft.VisualStudio.CoreEditor.log                                   10.05.2026 01:44:45    9461
dd_setup_20260510014438_070_Microsoft.VisualStudio.ErrorList.log                                    10.05.2026 01:44:45    6014
dd_setup_20260510014438_069_Microsoft.VisualStudio.Finalizer.log                                    10.05.2026 01:44:45    4239
dd_setup_20260510014438_068_Microsoft.VisualStudio.Log.Resources.log                                10.05.2026 01:44:45     540
dd_setup_20260510014438_067_Microsoft.VisualStudio.Log.Targeted.log                                 10.05.2026 01:44:45     608
dd_setup_20260510014438_066_Microsoft.VisualStudio.Log.log                                          10.05.2026 01:44:45    4256
dd_setup_20260510014438_065_Microsoft.VisualStudio.NgenRunner.log                                   10.05.2026 01:44:45     783
dd_setup_20260510014438_064_Microsoft.VisualStudio.MinShell.Interop.log                             10.05.2026 01:44:45   14819
dd_setup_20260510014438_063_Microsoft.VisualStudio.OpenFolder.VSIX.log                              10.05.2026 01:44:45   32787
dd_setup_20260510014438_062_Microsoft.ServiceHub.Managed.log                                        10.05.2026 01:44:45   16847
dd_setup_20260510014438_061_Microsoft.ServiceHub.Node.log                                           10.05.2026 01:44:44    2029
dd_setup_20260510014438_060_Microsoft.VisualStudio.Platform.Markdown.log                            10.05.2026 01:44:44   12439
dd_setup_20260510014438_059_Microsoft.VisualStudio.TextMateGrammars.log                             10.05.2026 01:44:44  116088
dd_setup_20260510014438_058_Microsoft.VisualStudio.GraphProvider.Auto.log                           10.05.2026 01:44:44    2356
dd_setup_20260510014438_057_Microsoft.VisualStudio.GraphProvider.log                                10.05.2026 01:44:44    3902
dd_setup_20260510014438_056_Microsoft.VisualStudio.GraphModel.log                                   10.05.2026 01:44:44     921
dd_setup_20260510014438_055_Microsoft.VisualStudio.PerformanceProvider.log                          10.05.2026 01:44:44     660
dd_setup_20260510014438_054_Microsoft.VisualStudio.VirtualTree.log                                  10.05.2026 01:44:44     628
dd_setup_20260510014438_053_Microsoft.VisualStudio.ScriptedHost.Targeted.log                        10.05.2026 01:44:44     580
dd_setup_20260510014438_052_Microsoft.VisualStudio.ScriptedHost.log                                 10.05.2026 01:44:44    1752
dd_setup_20260510014438_051_Microsoft.DiagnosticsHub.Collection.log                                 10.05.2026 01:44:44    5373
dd_setup_20260510014438_050_Microsoft.DiagnosticsHub.Runtime.log                                    10.05.2026 01:44:44   36386
dd_setup_20260510014438_049_Microsoft.VisualStudio.Community.ProductArch.Neutral.log                10.05.2026 01:44:44   45426
dd_setup_20260510014438_048_Microsoft.VisualStudio.Platform.CallHierarchy.log                       10.05.2026 01:44:44    6886
dd_setup_20260510014438_047_Microsoft.MSHtml.log                                                    10.05.2026 01:44:44     582
dd_setup_20260510014438_046_Microsoft.VisualStudio.Diagnostics.AspNetHelper.log                     10.05.2026 01:44:44     306
dd_setup_20260510014438_045_Microsoft.VisualStudio.WebSiteProject.DTE.log                           10.05.2026 01:44:44    1140
dd_setup_20260510014438_044_Microsoft.VisualStudio.Community.ProductArch.Resources.Neutral.log      10.05.2026 01:44:44   16945
dd_setup_20260510014438_043_Microsoft.VisualStudio.Community.ProductArch.Resources.NeutralExtra.log 10.05.2026 01:44:44   32857
dd_setup_20260510014438_042_Microsoft.VisualStudio.Community.ProductArch.Resources.Targeted.log     10.05.2026 01:44:44    3491
dd_setup_20260510014438_041_Microsoft.VisualStudio.Community.CSharp.Resources.Neutral.log           10.05.2026 01:44:44   20273
dd_setup_20260510014438_040_Microsoft.VisualStudio.Community.CSharp.Resources.Targeted.log          10.05.2026 01:44:44     550
dd_setup_20260510014438_039_Microsoft.VisualStudio.Community.VB.Resources.Neutral.log               10.05.2026 01:44:44  111144
dd_setup_20260510014438_038_Microsoft.VisualStudio.Community.VB.Resources.Targeted.log              10.05.2026 01:44:43     998
dd_setup_20260510014438_037_Microsoft.IntelliTrace.CollectorCab.log                                 10.05.2026 01:44:43     971
dd_setup_20260510014438_036_Microsoft.VisualStudio.Community.ProductArch.NeutralExtra.log           10.05.2026 01:44:43    4968
dd_setup_20260510014438_035_Microsoft.VisualStudio.Community.ProductArch.Targeted.log               10.05.2026 01:44:43   10392
dd_setup_20260510014438_034_Microsoft.VisualStudio.Community.ProductArch.TargetedExtra.log          10.05.2026 01:44:43    1682
dd_setup_20260510014438_033_Microsoft.VisualStudio.Community.CSharp.Neutral.log                     10.05.2026 01:44:43    7760
dd_setup_20260510014438_032_Microsoft.VisualStudio.Community.CSharp.Targeted.log                    10.05.2026 01:44:43    1660
dd_setup_20260510014438_031_Microsoft.VisualStudio.Community.VB.Neutral.log                         10.05.2026 01:44:43    3742
dd_setup_20260510014438_030_Microsoft.VisualStudio.Community.VB.Targeted.log                        10.05.2026 01:44:43    1177
dd_setup_20260510014438_029_Microsoft.VisualStudio.Community.x64.log                                10.05.2026 01:44:43    1441
dd_setup_20260510014438_028_Microsoft.VisualStudio.Community.x86.log                                10.05.2026 01:44:43    1475
dd_setup_20260510014438_027_Microsoft.VisualStudio.ProjectSystem.log                                10.05.2026 01:44:43   17450
dd_setup_20260510014438_026_Microsoft.VisualStudio.ProjectSystem.Query.log                          10.05.2026 01:44:43   10995
dd_setup_20260510014438_025_Microsoft.VisualStudio.LiveShareApi.log                                 10.05.2026 01:44:43     648
dd_setup_20260510014438_024_Microsoft.VisualStudio.ProjectSystem.Full.log                           10.05.2026 01:44:43     584
dd_setup_20260510014438_023_Microsoft.VisualStudio.ClientDiagnostics.Resources.log                  10.05.2026 01:44:43     712
dd_setup_20260510014438_022_Microsoft.VisualStudio.ClientDiagnostics.Targeted.log                   10.05.2026 01:44:43     957
dd_setup_20260510014438_021_Microsoft.VisualStudio.ClientDiagnostics.log                            10.05.2026 01:44:43    4434
dd_setup_20260510014438_020_Microsoft.VisualStudio.AppResponsiveness.Resources.log                  10.05.2026 01:44:43    1530
dd_setup_20260510014438_019_Microsoft.VisualStudio.AppResponsiveness.Targeted.log                   10.05.2026 01:44:43     692
dd_setup_20260510014438_018_Microsoft.VisualStudio.AppResponsiveness.log                            10.05.2026 01:44:43   18193
dd_setup_20260510014438_017_Microsoft.VisualStudio.TestTools.TeamFoundationClient.log               10.05.2026 01:44:43   12338
dd_setup_20260510014438_016_Microsoft.VisualStudio.CodeSense.Community.log                          10.05.2026 01:44:43    2367
dd_setup_20260510014438_015_Microsoft.VisualStudio.VC.Ide.MDD.log                                   10.05.2026 01:44:43    7940
dd_setup_20260510014438_014_Microsoft.VisualStudio.VC.Items.Pro.log                                 10.05.2026 01:44:43    1674
dd_setup_20260510014438_013_Microsoft.VisualStudio.VC.Templates.General.Resources.log               10.05.2026 01:44:43    5072
dd_setup_20260510014438_012_Microsoft.VisualStudio.VC.Templates.General.log                         10.05.2026 01:44:43   16521
dd_setup_20260510014438_011_Microsoft.VisualStudio.VC.Ide.Pro.Resources.log                         10.05.2026 01:44:43    5808
dd_setup_20260510014438_010_Microsoft.VisualStudio.VC.Ide.Pro.log                                   10.05.2026 01:44:43     292
dd_setup_20260510014438_009_Microsoft.VisualStudio.VC.Templates.Desktop.log                         10.05.2026 01:44:43    6900
dd_setup_20260510014438_008_Microsoft.VisualStudio.VC.Templates.UnitTest.Resources.log              10.05.2026 01:44:43    1964
dd_setup_20260510014438_007_Microsoft.VisualStudio.VC.Templates.UnitTest.log                        10.05.2026 01:44:43    3140
dd_setup_20260510014438_006_Microsoft.VisualStudio.TestTools.TestPlatform.IDE.log                   10.05.2026 01:44:43  372937
dd_setup_20260510014438_005_Microsoft.VisualStudio.TestTools.TestWIExtension.log                    10.05.2026 01:44:42    1584
dd_setup_20260510014438_004_Microsoft.VisualStudio.VC.Ide.Linux.ConnectionManager.Resources.log     10.05.2026 01:44:42    4237
dd_setup_20260510014438_003_Microsoft.VisualStudio.VC.Ide.Linux.Shared.Resources.log                10.05.2026 01:44:42     648
dd_setup_20260510014438_002_Microsoft.VisualStudio.VC.Ide.Linux.Shared.log                          10.05.2026 01:44:42     622
dd_setup_20260510014438_001_Microsoft.VisualStudio.VC.Ide.Linux.ConnectionManager.log               10.05.2026 01:44:42    6595
dd_setup_20260510014438_errors.log                                                                  10.05.2026 01:44:38       0
dd_setup_20260510014434.log                                                                         10.05.2026 01:44:36    7846
dd_setup_20260510014434_errors.log                                                                  10.05.2026 01:44:34       0
dd_bootstrapper_20260510013538.log                                                                  10.05.2026 01:36:12    5744
dd_installer_20260510013540.log                                                                     10.05.2026 01:36:12   33755
dd_installer_elevated_20260510013544.log                                                            10.05.2026 01:36:12 3658706
dd_setup_20260510013610.log                                                                         10.05.2026 01:36:11    8310
dd_setup_20260510013610_errors.log                                                                  10.05.2026 01:36:10       0
dd_setup_20260510013545.log                                                                         10.05.2026 01:36:10 3648592
dd_setup_20260510013545_218_Microsoft.VisualStudio.VC.Ide.Linux.ConnectionManager.log               10.05.2026 01:36:08   17991
dd_setup_20260510013545_217_Microsoft.VisualStudio.VC.Ide.Linux.Shared.log                          10.05.2026 01:36:08    1182
dd_setup_20260510013545_216_Microsoft.VisualStudio.VC.Ide.Linux.Shared.Resources.log                10.05.2026 01:36:08    1260
dd_setup_20260510013545_215_Microsoft.VisualStudio.VC.Ide.Linux.ConnectionManager.Resources.log     10.05.2026 01:36:08   11403
dd_setup_20260510013545_214_Microsoft.VisualStudio.TestTools.TestWIExtension.log                    10.05.2026 01:36:08    3984
dd_setup_20260510013545_213_Microsoft.VisualStudio.TestTools.TestPlatform.IDE.log                   10.05.2026 01:36:08 1056826
dd_setup_20260510013545_212_Microsoft.VisualStudio.VC.Templates.UnitTest.log                        10.05.2026 01:36:06    8256
dd_setup_20260510013545_211_Microsoft.VisualStudio.VC.Templates.UnitTest.Resources.log              10.05.2026 01:36:06    4968
dd_setup_20260510013545_210_Microsoft.VisualStudio.VC.Templates.Desktop.log                         10.05.2026 01:36:06   18816
dd_setup_20260510013545_209_Microsoft.VisualStudio.VC.Ide.Pro.log                                   10.05.2026 01:36:06     309
dd_setup_20260510013545_208_Microsoft.VisualStudio.VC.Ide.Pro.Resources.log                         10.05.2026 01:36:06   15780
dd_setup_20260510013545_207_Microsoft.VisualStudio.VC.Templates.General.log                         10.05.2026 01:36:06   45459
dd_setup_20260510013545_206_Microsoft.VisualStudio.VC.Templates.General.Resources.log               10.05.2026 01:36:06   13692
dd_setup_20260510013545_205_Microsoft.VisualStudio.VC.Items.Pro.log                                 10.05.2026 01:36:06    4098
dd_setup_20260510013545_204_Microsoft.VisualStudio.VC.Ide.MDD.log                                   10.05.2026 01:36:06   21816
dd_setup_20260510013545_203_Microsoft.VisualStudio.CodeSense.Community.log                          10.05.2026 01:36:06    7282
dd_setup_20260510013545_202_Microsoft.VisualStudio.TestTools.TeamFoundationClient.log               10.05.2026 01:36:06   39528
dd_setup_20260510013545_201_Microsoft.VisualStudio.AppResponsiveness.log                            10.05.2026 01:36:06   51195
dd_setup_20260510013545_200_Microsoft.VisualStudio.AppResponsiveness.Targeted.log                   10.05.2026 01:36:06    1392
dd_setup_20260510013545_199_Microsoft.VisualStudio.AppResponsiveness.Resources.log                  10.05.2026 01:36:06    3786
dd_setup_20260510013545_198_Microsoft.VisualStudio.ClientDiagnostics.log                            10.05.2026 01:36:06   11898
dd_setup_20260510013545_197_Microsoft.VisualStudio.ClientDiagnostics.Targeted.log                   10.05.2026 01:36:06    2139
dd_setup_20260510013545_196_Microsoft.VisualStudio.ClientDiagnostics.Resources.log                  10.05.2026 01:36:06    1452
dd_setup_20260510013545_195_Microsoft.VisualStudio.ProjectSystem.Full.log                           10.05.2026 01:36:06     594
dd_setup_20260510013545_194_Microsoft.VisualStudio.LiveShareApi.log                                 10.05.2026 01:36:06    1260
dd_setup_20260510013545_193_Microsoft.VisualStudio.ProjectSystem.Query.log                          10.05.2026 01:36:06   31131
dd_setup_20260510013545_192_Microsoft.VisualStudio.ProjectSystem.log                                10.05.2026 01:36:06   49894
dd_setup_20260510013545_191_Microsoft.VisualStudio.Community.x86.log                                10.05.2026 01:36:05    3567
dd_setup_20260510013545_190_Microsoft.VisualStudio.Community.x64.log                                10.05.2026 01:36:05    3393
dd_setup_20260510013545_189_Microsoft.VisualStudio.Community.VB.Targeted.log                        10.05.2026 01:36:05    2667
dd_setup_20260510013545_188_Microsoft.VisualStudio.Community.VB.Neutral.log                         10.05.2026 01:36:05   10062
dd_setup_20260510013545_187_Microsoft.VisualStudio.Community.CSharp.Targeted.log                    10.05.2026 01:36:05    4347
dd_setup_20260510013545_186_Microsoft.VisualStudio.Community.CSharp.Neutral.log                     10.05.2026 01:36:05   21120
dd_setup_20260510013545_185_Microsoft.VisualStudio.Community.ProductArch.TargetedExtra.log          10.05.2026 01:36:05    4122
dd_setup_20260510013545_184_Microsoft.VisualStudio.Community.ProductArch.Targeted.log               10.05.2026 01:36:05   28655
dd_setup_20260510013545_183_Microsoft.VisualStudio.Community.ProductArch.NeutralExtra.log           10.05.2026 01:36:05   13500
dd_setup_20260510013545_182_Microsoft.IntelliTrace.CollectorCab.log                                 10.05.2026 01:36:05    2169
dd_setup_20260510013545_181_Microsoft.VisualStudio.Community.VB.Resources.Targeted.log              10.05.2026 01:36:05    2190
dd_setup_20260510013545_180_Microsoft.VisualStudio.Community.VB.Resources.Neutral.log               10.05.2026 01:36:05  314136
dd_setup_20260510013545_179_Microsoft.VisualStudio.Community.CSharp.Resources.Targeted.log          10.05.2026 01:36:05     972
dd_setup_20260510013545_178_Microsoft.VisualStudio.Community.CSharp.Resources.Neutral.log           10.05.2026 01:36:05   56763
dd_setup_20260510013545_177_Microsoft.VisualStudio.Community.ProductArch.Resources.Targeted.log     10.05.2026 01:36:05    9147
dd_setup_20260510013545_176_Microsoft.VisualStudio.Community.ProductArch.Resources.NeutralExtra.log 10.05.2026 01:36:05   33943
dd_setup_20260510013545_175_Microsoft.VisualStudio.Community.ProductArch.Resources.Neutral.log      10.05.2026 01:36:05   46611
dd_setup_20260510013545_174_Microsoft.VisualStudio.WebSiteProject.DTE.log                           10.05.2026 01:36:05    2616
dd_setup_20260510013545_173_Microsoft.VisualStudio.Diagnostics.AspNetHelper.log                     10.05.2026 01:36:05     309
dd_setup_20260510013545_172_Microsoft.MSHtml.log                                                    10.05.2026 01:36:05    1062
dd_setup_20260510013545_171_Microsoft.VisualStudio.Platform.CallHierarchy.log                       10.05.2026 01:36:05   18894
dd_setup_20260510013545_170_Microsoft.VisualStudio.Community.ProductArch.Neutral.log                10.05.2026 01:36:04  132431
dd_setup_20260510013545_169_Microsoft.DiagnosticsHub.Runtime.log                                    10.05.2026 01:36:04  103872
dd_setup_20260510013545_168_Microsoft.DiagnosticsHub.Collection.log                                 10.05.2026 01:36:04   14631
dd_setup_20260510013545_167_Microsoft.VisualStudio.ScriptedHost.log                                 10.05.2026 01:36:04    4671
dd_setup_20260510013545_166_Microsoft.VisualStudio.ScriptedHost.Targeted.log                        10.05.2026 01:36:04    1056
dd_setup_20260510013545_165_Microsoft.VisualStudio.VirtualTree.log                                  10.05.2026 01:36:04    1200
dd_setup_20260510013545_164_Microsoft.VisualStudio.PerformanceProvider.log                          10.05.2026 01:36:04    1673
dd_setup_20260510013545_163_Microsoft.VisualStudio.GraphModel.log                                   10.05.2026 01:36:04    2352
dd_setup_20260510013545_162_Microsoft.VisualStudio.GraphProvider.log                                10.05.2026 01:36:04   13615
dd_setup_20260510013545_161_Microsoft.VisualStudio.GraphProvider.Auto.log                           10.05.2026 01:36:04    7084
dd_setup_20260510013545_160_Microsoft.VisualStudio.TextMateGrammars.log                             10.05.2026 01:36:04  318581
dd_setup_20260510013545_159_Microsoft.VisualStudio.Platform.Markdown.log                            10.05.2026 01:36:04   34233
dd_setup_20260510013545_158_Microsoft.ServiceHub.Node.log                                           10.05.2026 01:36:04    5103
dd_setup_20260510013545_157_Microsoft.ServiceHub.Managed.log                                        10.05.2026 01:36:04   48738
dd_setup_20260510013545_156_Microsoft.VisualStudio.OpenFolder.VSIX.log                              10.05.2026 01:36:04   94695
dd_setup_20260510013545_155_Microsoft.VisualStudio.MinShell.Interop.log                             10.05.2026 01:36:03   41507
dd_setup_20260510013545_154_Microsoft.VisualStudio.NgenRunner.log                                   10.05.2026 01:36:03    1605
dd_setup_20260510013545_153_Microsoft.VisualStudio.Log.log                                          10.05.2026 01:36:03   11798
dd_setup_20260510013545_152_Microsoft.VisualStudio.Log.Targeted.log                                 10.05.2026 01:36:03    1146
dd_setup_20260510013545_151_Microsoft.VisualStudio.Log.Resources.log                                10.05.2026 01:36:03     936
dd_setup_20260510013545_150_Microsoft.VisualStudio.Finalizer.log                                    10.05.2026 01:36:03   11253
dd_setup_20260510013545_149_Microsoft.VisualStudio.ErrorList.log                                    10.05.2026 01:36:03   16597
dd_setup_20260510013545_148_Microsoft.VisualStudio.CoreEditor.log                                   10.05.2026 01:36:03   25707
dd_setup_20260510013545_147_Microsoft.VisualStudio.CoreEditor.UserProfiles.log                      10.05.2026 01:36:03    5088
dd_setup_20260510013545_146_Microsoft.VisualStudio.Platform.NavigateTo.log                          10.05.2026 01:36:03    5085
dd_setup_20260510013545_145_Microsoft.VisualStudio.Connected.log                                    10.05.2026 01:36:03   29386
dd_setup_20260510013545_144_Microsoft.VisualStudio.Identity.log                                     10.05.2026 01:36:03  491097
dd_setup_20260510013545_143_Microsoft.Developer.IdentityServiceGS.log                               10.05.2026 01:36:02   16167
dd_setup_20260510013545_142_SQLitePCLRaw.log                                                        10.05.2026 01:36:02    4925
dd_setup_20260510013545_141_SQLitePCLRaw.Targeted.log                                               10.05.2026 01:36:02    1206
dd_setup_20260510013545_140_Microsoft.VisualStudio.Connected.Auto.log                               10.05.2026 01:36:02    3741
dd_setup_20260510013545_139_Microsoft.VisualStudio.Connected.Auto.Resources.log                     10.05.2026 01:36:02    1278
dd_setup_20260510013545_138_Microsoft.VisualStudio.Connected.Resources.log                          10.05.2026 01:36:02     309
dd_setup_20260510013545_137_Microsoft.VisualStudio.VC.Ide.x64.log                                   10.05.2026 01:36:02    1020
dd_setup_20260510013545_136_Microsoft.VisualStudio.Debugger.Script.log                              10.05.2026 01:36:02    2802
dd_setup_20260510013545_135_Microsoft.VisualStudio.Debugger.Script.Resources.log                    10.05.2026 01:36:02    1140
dd_setup_20260510013545_134_Microsoft.VisualStudio.Debugger.Script.Remote.log                       10.05.2026 01:36:02    1929
dd_setup_20260510013545_133_Microsoft.VisualStudio.Debugger.Script.Remote.log                       10.05.2026 01:36:02    1917
dd_setup_20260510013545_132_Microsoft.VisualStudio.Debugger.Script.Remote.Resources.log             10.05.2026 01:36:02    1182
dd_setup_20260510013545_131_Microsoft.VisualStudio.Debugger.Script.Remote.Resources.log             10.05.2026 01:36:02    1182
dd_setup_20260510013545_130_Microsoft.VisualStudio.VC.Ide.WinXPlus.log                              10.05.2026 01:36:02   19857
dd_setup_20260510013545_129_Microsoft.VisualStudio.VC.Ide.Dskx.log                                  10.05.2026 01:36:02    4914
dd_setup_20260510013545_128_Microsoft.VisualStudio.VC.Ide.Dskx.Resources.log                        10.05.2026 01:36:02    1623
dd_setup_20260510013545_127_Microsoft.VisualStudio.VC.Ide.Base.log                                  10.05.2026 01:36:01  119658
dd_setup_20260510013545_126_Microsoft.VisualStudio.VC.Ide.LanguageService.log                       10.05.2026 01:36:01   53309
dd_setup_20260510013545_125_Microsoft.VisualStudio.VC.Copilot.Setup.log                             10.05.2026 01:36:01    4227
dd_setup_20260510013545_124_Microsoft.VisualStudio.VC.Ide.VCPkgDatabase.log                         10.05.2026 01:36:01    1164
dd_setup_20260510013545_123_Microsoft.VisualStudio.VC.Ide.ResourceEditor.log                        10.05.2026 01:36:01   11892
dd_setup_20260510013545_122_Microsoft.VisualStudio.VC.Ide.ResourceEditor.Resources.log              10.05.2026 01:36:01    3219
dd_setup_20260510013545_121_Microsoft.VisualStudio.VC.Ide.LanguageService.Dependencies.log          10.05.2026 01:36:01    2199
dd_setup_20260510013545_120_Microsoft.VisualStudio.VC.Ide.Core.log                                  10.05.2026 01:36:01    6327
dd_setup_20260510013545_119_Microsoft.VisualStudio.VisualC.Utilities.log                            10.05.2026 01:36:01    2103
dd_setup_20260510013545_118_Microsoft.VisualStudio.VisualC.Utilities.Resources.log                  10.05.2026 01:36:01     309
dd_setup_20260510013545_117_Microsoft.VisualStudio.VC.Ide.ProjectSystem.log                         10.05.2026 01:36:01   18272
dd_setup_20260510013545_116_Microsoft.VisualStudio.VC.Ide.ProjectSystem.Resources.log               10.05.2026 01:36:01    4350
dd_setup_20260510013545_115_Microsoft.VisualStudio.VC.Ide.Core.VCProjectEngine.log                  10.05.2026 01:36:01    1194
dd_setup_20260510013545_114_Microsoft.VisualStudio.VC.Ide.Core.VCProjectEngine.Resources.log        10.05.2026 01:36:01    1212
dd_setup_20260510013545_113_Microsoft.VisualStudio.VC.Ide.LanguageService.Resources.log             10.05.2026 01:36:01   45036
dd_setup_20260510013545_112_Microsoft.VisualStudio.VC.Llvm.Base.log                                 10.05.2026 01:36:01   78315
dd_setup_20260510013545_111_Microsoft.VisualStudio.VC.Ide.Base.Resources.log                        10.05.2026 01:36:00    3663
dd_setup_20260510013545_110_Microsoft.VisualStudio.Debugger.BrokeredServices.log                    10.05.2026 01:36:00   17449
dd_setup_20260510013545_109_Microsoft.VisualStudio.Debugger.VSCodeDebuggerHost.log                  10.05.2026 01:36:00   21441
dd_setup_20260510013545_108_Microsoft.VisualStudio.Debugger.AzureAttach.log                         10.05.2026 01:36:00    2373
dd_setup_20260510013545_107_Microsoft.VisualStudio.Web.Azure.Common.log                             10.05.2026 01:36:00    9699
dd_setup_20260510013545_106_Microsoft.WebTools.Shared.log                                           10.05.2026 01:35:59  415675
dd_setup_20260510013545_105_Microsoft.WebTools.DotNet.Core.ItemTemplates.log                        10.05.2026 01:35:59    7392
dd_setup_20260510013545_104_Microsoft.VisualStudio.VC.Ide.Debugger.log                              10.05.2026 01:35:59   23592
dd_setup_20260510013545_103_Microsoft.VisualStudio.VC.Ide.Debugger.Concord.log                      10.05.2026 01:35:59    3507
dd_setup_20260510013545_102_Microsoft.VisualStudio.VC.Ide.Debugger.Concord.Resources.log            10.05.2026 01:35:59    1713
dd_setup_20260510013545_101_Microsoft.VisualStudio.VC.Ide.Debugger.Resources.log                    10.05.2026 01:35:59    1857
dd_setup_20260510013545_100_Microsoft.VisualStudio.VC.Ide.Common.log                                10.05.2026 01:35:59   11508
dd_setup_20260510013545_099_Microsoft.VisualStudio.VC.Ide.Common.Resources.log                      10.05.2026 01:35:59    1677
dd_setup_20260510013545_098_Microsoft.VisualStudio.Debugger.CollectionAgents.log                    10.05.2026 01:35:59    2073
dd_setup_20260510013545_097_Microsoft.VisualStudio.Debugger.Parallel.log                            10.05.2026 01:35:59    7208
dd_setup_20260510013545_096_Microsoft.VisualStudio.Debugger.Parallel.Resources.log                  10.05.2026 01:35:59    1182
dd_setup_20260510013545_095_Microsoft.VisualStudio.Debugger.Managed.log                             10.05.2026 01:35:59   43959
dd_setup_20260510013545_094_Microsoft.DiaSymReader.log                                              10.05.2026 01:35:59    1104
dd_setup_20260510013545_093_Microsoft.CodeAnalysis.ExpressionEvaluator.log                          10.05.2026 01:35:59   51786
dd_setup_20260510013545_092_Microsoft.VisualStudio.Debugger.Concord.Managed.log                     10.05.2026 01:35:59   10304
dd_setup_20260510013545_091_Microsoft.VisualStudio.Debugger.Concord.Managed.Resources.log           10.05.2026 01:35:59     309
dd_setup_20260510013545_090_Microsoft.VisualStudio.Debugger.Managed.Resources.log                   10.05.2026 01:35:59    2013
dd_setup_20260510013545_089_Microsoft.VisualStudio.Debugger.TargetComposition.log                   10.05.2026 01:35:59    2202
dd_setup_20260510013545_088_Microsoft.VisualStudio.Debugger.TargetComposition.Remote.log            10.05.2026 01:35:59    2580
dd_setup_20260510013545_087_Microsoft.VisualStudio.Debugger.TargetComposition.Remote.log            10.05.2026 01:35:59    2580
dd_setup_20260510013545_086_Microsoft.VisualStudio.Debugger.Remote.log                              10.05.2026 01:35:59   76719
dd_setup_20260510013545_085_Microsoft.VisualStudio.Debugger.Concord.Remote.log                      10.05.2026 01:35:58   14805
dd_setup_20260510013545_084_Microsoft.VisualStudio.Debugger.Concord.Remote.Resources.log            10.05.2026 01:35:58    1170
dd_setup_20260510013545_083_Microsoft.VisualStudio.Debugger.Remote.log                              10.05.2026 01:35:58   77562
dd_setup_20260510013545_082_Microsoft.VisualStudio.Debugger.Concord.Remote.log                      10.05.2026 01:35:58   13134
dd_setup_20260510013545_081_Microsoft.VisualStudio.Debugger.Concord.Remote.Resources.log            10.05.2026 01:35:58    1170
dd_setup_20260510013545_080_Microsoft.VisualStudio.Debugger.Remote.Resources.log                    10.05.2026 01:35:58    2670
dd_setup_20260510013545_079_Microsoft.VisualStudio.Debugger.Remote.Resources.log                    10.05.2026 01:35:58    3495
dd_setup_20260510013545_078_Microsoft.VisualStudio.Debugger.log                                     10.05.2026 01:35:58   77822
dd_setup_20260510013545_077_Microsoft.VisualStudio.AzureSDK.log                                     10.05.2026 01:35:58    8316
dd_setup_20260510013545_076_Microsoft.VisualStudio.Editors.log                                      10.05.2026 01:35:58   30075
dd_setup_20260510013545_075_Microsoft.VisualStudio.VC.MSVCDis.log                                   10.05.2026 01:35:58     924
dd_setup_20260510013545_074_Microsoft.IntelliTrace.DiagnosticsHub.log                               10.05.2026 01:35:58   14729
dd_setup_20260510013545_073_Microsoft.VisualStudio.MinShell.log                                     10.05.2026 01:35:58   90275
dd_setup_20260510013545_072_Microsoft.VisualStudio.OpenTelemetry.Collector.netfx.log                10.05.2026 01:35:57    1446
dd_setup_20260510013545_071_Microsoft.VisualStudio.OpenTelemetry.ClientExtensions.netfx.log         10.05.2026 01:35:57    4677
dd_setup_20260510013545_070_Microsoft.VisualStudio.Copilot.Contracts.log                            10.05.2026 01:35:57    9663
dd_setup_20260510013545_069_Microsoft.VisualStudio.Licensing.log                                    10.05.2026 01:35:57    2142
dd_setup_20260510013545_068_Microsoft.VisualStudio.IdentityDependencies.log                         10.05.2026 01:35:57   10335
dd_setup_20260510013545_067_Microsoft.VisualStudio.Extensibility.Container.log                      10.05.2026 01:35:57   46635
dd_setup_20260510013545_066_Microsoft.VisualStudio.LanguageServer.log                               10.05.2026 01:35:57   37933
dd_setup_20260510013545_065_Microsoft.VisualStudio.MefHosting.log                                   10.05.2026 01:35:57    6697
dd_setup_20260510013545_064_Microsoft.VisualStudio.Initializer.log                                  10.05.2026 01:35:57    1326
dd_setup_20260510013545_063_Microsoft.VisualStudio.ExtensionManager.log                             10.05.2026 01:35:57   41128
dd_setup_20260510013545_062_Microsoft.VisualStudio.ExtensionManager.Auto.log                        10.05.2026 01:35:57    4964
dd_setup_20260510013545_061_Microsoft.VisualStudio.Platform.Editor.log                              10.05.2026 01:35:57   85085
dd_setup_20260510013545_060_Microsoft.VisualStudio.MinShell.Targeted.log                            10.05.2026 01:35:57  107187
dd_setup_20260510013545_059_Microsoft.VisualStudio.Devenv.Config.log                                10.05.2026 01:35:56     918
dd_setup_20260510013545_058_Microsoft.VisualStudio.MinShell.Resources.log                           10.05.2026 01:35:56   10477
dd_setup_20260510013545_057_Microsoft.VisualStudio.UIInternal.Guide.log                             10.05.2026 01:35:56  194262
dd_setup_20260510013545_056_Microsoft.VisualStudio.UIInternal.log                                   10.05.2026 01:35:56  116629
dd_setup_20260510013545_055_Microsoft.VisualStudio.UIInternal.Resources.log                         10.05.2026 01:35:56    1182
dd_setup_20260510013545_054_Microsoft.VisualStudio.CoreDotNet.log                                   10.05.2026 01:35:56   62586
dd_setup_20260510013545_053_Microsoft.VisualStudio.MinShell.Auto.log                                10.05.2026 01:35:56   36514
dd_setup_20260510013545_052_Microsoft.VisualStudio.MinShell.Auto.Resources.log                      10.05.2026 01:35:55    4824
dd_setup_20260510013545_051_Microsoft.VisualStudio.Debugger.Concord.log                             10.05.2026 01:35:55   22481
dd_setup_20260510013545_050_Microsoft.VisualStudio.Debugger.Concord.Resources.log                   10.05.2026 01:35:55    2157
dd_setup_20260510013545_049_Microsoft.VisualStudio.Debugger.Resources.log                           10.05.2026 01:35:55    5323
dd_setup_20260510013545_048_Microsoft.DiaSymReader.PortablePdb.log                                  10.05.2026 01:35:55    1176
dd_setup_20260510013545_047_Microsoft.VisualStudio.PerfLib.log                                      10.05.2026 01:35:55    8469
dd_setup_20260510013545_046_Microsoft.VisualStudio.Debugger.Package.DiagHub.Client.log              10.05.2026 01:35:55    1110
dd_setup_20260510013545_045_Microsoft.VisualStudio.Debugger.Remote.DiagnosticsHub.Client.log        10.05.2026 01:35:55    1152
dd_setup_20260510013545_044_Microsoft.VisualStudio.Debugger.Remote.DiagnosticsHub.Client.log        10.05.2026 01:35:55    1152
dd_setup_20260510013545_043_Microsoft.VisualStudio.TextTemplating.MSBuild.log                       10.05.2026 01:35:55   13308
dd_setup_20260510013545_042_Microsoft.VisualStudio.TextTemplating.Integration.log                   10.05.2026 01:35:55   23722
dd_setup_20260510013545_041_Microsoft.VisualStudio.TextTemplating.Core.log                          10.05.2026 01:35:55   17887
dd_setup_20260510013545_040_Microsoft.CodeAnalysis.VisualStudio.Setup.log                           10.05.2026 01:35:55  711239
dd_setup_20260510013545_039_Microsoft.VisualStudio.TextTemplating.Integration.Resources.log         10.05.2026 01:35:54     586
dd_setup_20260510013545_038_Microsoft.VisualStudio.TestTools.DynamicCodeCoverage.log                10.05.2026 01:35:54   46134
dd_setup_20260510013545_037_Microsoft.VisualStudio.InstrumentationEngine.log                        10.05.2026 01:35:53    2451
dd_setup_20260510013545_036_Microsoft.CodeCoverage.Console.Targeted.log                             10.05.2026 01:35:53   74943
dd_setup_20260510013545_035_Microsoft.VisualStudio.TestTools.TestPlatform.V1.CLI.log                10.05.2026 01:35:53    6918
dd_setup_20260510013545_034_Microsoft.VisualStudio.TestTools.TestPlatform.V2.CLI.log                10.05.2026 01:35:53  414069
dd_setup_20260510013545_033_Microsoft.VisualStudio.VC.UnitTest.Desktop.Build.Core.log               10.05.2026 01:35:52   13707
dd_setup_20260510013545_032_Microsoft.VisualStudio.TestTools.TestPlatform.V1.CPP.log                10.05.2026 01:35:52    1416
dd_setup_20260510013545_031_Microsoft.VisualCpp.Tools.Common.Utils.log                              10.05.2026 01:35:52    4581
dd_setup_20260510013545_030_Microsoft.VisualCpp.Tools.Common.Utils.Resources.log                    10.05.2026 01:35:52    1611
dd_setup_20260510013545_029_Microsoft.VisualCpp.Servicing.Redist.log                                10.05.2026 01:35:52    3681
dd_setup_20260510013545_028_Microsoft.VisualStudio.VC.vcvars.log                                    10.05.2026 01:35:52    1731
dd_setup_20260510013545_027_Microsoft.VS.VC.vcvars.x86.Shortcuts.log                                10.05.2026 01:35:52     309
dd_setup_20260510013545_026_Microsoft.VS.VC.vcvars.x64.Shortcuts.log                                10.05.2026 01:35:52     309
dd_setup_20260510013545_025_Microsoft.VisualStudio.VC.MSBuild.v170.x86.v143.log                     10.05.2026 01:35:52    2163
dd_setup_20260510013545_024_Microsoft.VisualStudio.VC.MSBuild.v170.X86.log                          10.05.2026 01:35:52    3591
dd_setup_20260510013545_023_Microsoft.VisualStudio.VC.MSBuild.v170.X64.v143.log                     10.05.2026 01:35:52    2139
dd_setup_20260510013545_022_Microsoft.VisualStudio.VC.MSBuild.v170.X64.log                          10.05.2026 01:35:52    3543
dd_setup_20260510013545_021_Microsoft.VisualStudio.VC.MSBuild.v170.ARM.v143.log                     10.05.2026 01:35:52    2139
dd_setup_20260510013545_020_Microsoft.VisualStudio.VC.MSBuild.v170.ARM.log                          10.05.2026 01:35:52    3543
dd_setup_20260510013545_019_Microsoft.VisualStudio.VC.MSBuild.v170.Base.log                         10.05.2026 01:35:52   82602
dd_setup_20260510013545_018_Microsoft.VisualStudio.VC.MSBuild.v170.Base.Resources.log               10.05.2026 01:35:52   38712
dd_setup_20260510013545_017_Microsoft.VisualStudio.Setup.Configuration.Interop.log                  10.05.2026 01:35:52    1272
dd_setup_20260510013545_016_Microsoft.VisualStudio.VsDevCmd.Ext.NetFxSdk.log                        10.05.2026 01:35:52    1002
dd_setup_20260510013545_015_Microsoft.VisualStudio.VsDevCmd.Core.WinSdk.log                         10.05.2026 01:35:52     996
dd_setup_20260510013545_014_Microsoft.VisualStudio.VsDevCmd.Core.DotNet.log                         10.05.2026 01:35:52     996
dd_setup_20260510013545_013_Microsoft.VisualStudio.VC.DevCmd.log                                    10.05.2026 01:35:52    9594
dd_setup_20260510013545_012_Microsoft.VisualStudio.VC.DevCmd.Resources.log                          10.05.2026 01:35:52    1140
dd_setup_20260510013545_011_Microsoft.VisualStudio.BuildTools.Resources.log                         10.05.2026 01:35:52    1044
dd_setup_20260510013545_010_Microsoft.VisualStudio.Net.Eula.Resources.log                           10.05.2026 01:35:52     990
dd_setup_20260510013545_009_Microsoft.Build.Dependencies.log                                        10.05.2026 01:35:52  435036
dd_setup_20260510013545_008_Microsoft.PythonTools.BuildCore.Vsix.log                                10.05.2026 01:35:51   15561
dd_setup_20260510013545_007_Microsoft.NuGet.Build.Tasks.Setup.log                                   10.05.2026 01:35:51    6384
dd_setup_20260510013545_006_Microsoft.CodeAnalysis.Compilers.log                                    10.05.2026 01:35:51  106164
dd_setup_20260510013545_005_Microsoft.VisualStudio.NativeImageSupport.log                           10.05.2026 01:35:51    1497
dd_setup_20260510013545_004_Microsoft.Build.log                                                     10.05.2026 01:35:51  263505
dd_setup_20260510013545_003_Microsoft.VisualStudio.NuGet.BuildTools.log                             10.05.2026 01:35:50  224253
dd_setup_20260510013545_002_Microsoft.Build.UnGAC.log                                               10.05.2026 01:35:50    1491
dd_setup_20260510013545_001_Microsoft.VisualStudio.VC.Icons.log                                     10.05.2026 01:35:50     900
dd_setup_20260510013545_errors.log                                                                  10.05.2026 01:35:45       0
dd_setup_20260510013542.log                                                                         10.05.2026 01:35:43    6266
dd_setup_20260510013542_errors.log                                                                  10.05.2026 01:35:42       0
dd_installer_20260510011748.log                                                                     10.05.2026 01:30:14   47162
dd_installer_elevated_20260510012325.log                                                            10.05.2026 01:24:20 3722798
dd_setup_20260510012419.log                                                                         10.05.2026 01:24:20    7846
dd_setup_20260510012419_errors.log                                                                  10.05.2026 01:24:19       0
dd_setup_20260510012326.log                                                                         10.05.2026 01:24:19 3700990
dd_setup_20260510012326_243_Microsoft.VisualStudio.VC.Ide.Linux.ConnectionManager.log               10.05.2026 01:24:17   17991
dd_setup_20260510012326_242_Microsoft.VisualStudio.VC.Ide.Linux.Shared.log                          10.05.2026 01:24:17    1182
dd_setup_20260510012326_241_Microsoft.VisualStudio.VC.Ide.Linux.Shared.Resources.log                10.05.2026 01:24:17    1260
dd_setup_20260510012326_240_Microsoft.VisualStudio.VC.Ide.Linux.ConnectionManager.Resources.log     10.05.2026 01:24:17   11403
dd_setup_20260510012326_239_Microsoft.VisualStudio.TestTools.TestWIExtension.log                    10.05.2026 01:24:17    3984
dd_setup_20260510012326_238_Microsoft.VisualStudio.TestTools.TestPlatform.IDE.log                   10.05.2026 01:24:17 1056826
dd_setup_20260510012326_237_Microsoft.VisualStudio.VC.Templates.UnitTest.log                        10.05.2026 01:24:16    8256
dd_setup_20260510012326_236_Microsoft.VisualStudio.VC.Templates.UnitTest.Resources.log              10.05.2026 01:24:15    4968
dd_setup_20260510012326_235_Microsoft.VisualStudio.VC.Templates.Desktop.log                         10.05.2026 01:24:15   18816
dd_setup_20260510012326_234_Microsoft.VisualStudio.VC.Ide.Pro.log                                   10.05.2026 01:24:15     309
dd_setup_20260510012326_233_Microsoft.VisualStudio.VC.Ide.Pro.Resources.log                         10.05.2026 01:24:15   15780
dd_setup_20260510012326_232_Microsoft.VisualStudio.VC.Templates.General.log                         10.05.2026 01:24:15   45459
dd_setup_20260510012326_231_Microsoft.VisualStudio.VC.Templates.General.Resources.log               10.05.2026 01:24:15   13692
dd_setup_20260510012326_230_Microsoft.VisualStudio.VC.Items.Pro.log                                 10.05.2026 01:24:15    4098
dd_setup_20260510012326_229_Microsoft.VisualStudio.VC.Ide.MDD.log                                   10.05.2026 01:24:15   21816
dd_setup_20260510012326_228_Microsoft.VisualStudio.CodeSense.Community.log                          10.05.2026 01:24:15    7282
dd_setup_20260510012326_227_Microsoft.VisualStudio.TestTools.TeamFoundationClient.log               10.05.2026 01:24:15   39528
dd_setup_20260510012326_226_Microsoft.VisualStudio.AppResponsiveness.log                            10.05.2026 01:24:15   51195
dd_setup_20260510012326_225_Microsoft.VisualStudio.AppResponsiveness.Targeted.log                   10.05.2026 01:24:15    1392
dd_setup_20260510012326_224_Microsoft.VisualStudio.AppResponsiveness.Resources.log                  10.05.2026 01:24:15    3786
dd_setup_20260510012326_223_Microsoft.VisualStudio.ClientDiagnostics.log                            10.05.2026 01:24:15   11898
dd_setup_20260510012326_222_Microsoft.VisualStudio.ClientDiagnostics.Targeted.log                   10.05.2026 01:24:15    2139
dd_setup_20260510012326_221_Microsoft.VisualStudio.ClientDiagnostics.Resources.log                  10.05.2026 01:24:15    1452
dd_setup_20260510012326_220_Microsoft.VisualStudio.ProjectSystem.Full.log                           10.05.2026 01:24:15     594
dd_setup_20260510012326_219_Microsoft.VisualStudio.LiveShareApi.log                                 10.05.2026 01:24:15    1260
dd_setup_20260510012326_218_Microsoft.VisualStudio.ProjectSystem.Query.log                          10.05.2026 01:24:15   31131
dd_setup_20260510012326_217_Microsoft.VisualStudio.ProjectSystem.log                                10.05.2026 01:24:15   49894
dd_setup_20260510012326_216_Microsoft.VisualStudio.Community.x86.log                                10.05.2026 01:24:15    3567
dd_setup_20260510012326_215_Microsoft.VisualStudio.Community.x64.log                                10.05.2026 01:24:15    3393
dd_setup_20260510012326_214_Microsoft.VisualStudio.Community.VB.Targeted.log                        10.05.2026 01:24:14    2667
dd_setup_20260510012326_213_Microsoft.VisualStudio.Community.VB.Neutral.log                         10.05.2026 01:24:14   10062
dd_setup_20260510012326_212_Microsoft.VisualStudio.Community.CSharp.Targeted.log                    10.05.2026 01:24:14    4347
dd_setup_20260510012326_211_Microsoft.VisualStudio.Community.CSharp.Neutral.log                     10.05.2026 01:24:14   21120
dd_setup_20260510012326_210_Microsoft.VisualStudio.Community.ProductArch.TargetedExtra.log          10.05.2026 01:24:14    4122
dd_setup_20260510012326_209_Microsoft.VisualStudio.Community.ProductArch.Targeted.log               10.05.2026 01:24:14   28655
dd_setup_20260510012326_208_Microsoft.VisualStudio.Community.ProductArch.NeutralExtra.log           10.05.2026 01:24:14   13500
dd_setup_20260510012326_207_Microsoft.IntelliTrace.CollectorCab.log                                 10.05.2026 01:24:14    2169
dd_setup_20260510012326_206_Microsoft.VisualStudio.Community.VB.Resources.Targeted.log              10.05.2026 01:24:14    2190
dd_setup_20260510012326_205_Microsoft.VisualStudio.Community.VB.Resources.Neutral.log               10.05.2026 01:24:14  314136
dd_setup_20260510012326_204_Microsoft.VisualStudio.Community.CSharp.Resources.Targeted.log          10.05.2026 01:24:14     972
dd_setup_20260510012326_203_Microsoft.VisualStudio.Community.CSharp.Resources.Neutral.log           10.05.2026 01:24:14   56763
dd_setup_20260510012326_202_Microsoft.VisualStudio.Community.ProductArch.Resources.Targeted.log     10.05.2026 01:24:14    9147
dd_setup_20260510012326_201_Microsoft.VisualStudio.Community.ProductArch.Resources.NeutralExtra.log 10.05.2026 01:24:14   33943
dd_setup_20260510012326_200_Microsoft.VisualStudio.Community.ProductArch.Resources.Neutral.log      10.05.2026 01:24:14   46611
dd_setup_20260510012326_199_Microsoft.VisualStudio.WebSiteProject.DTE.log                           10.05.2026 01:24:13    2616
dd_setup_20260510012326_198_Microsoft.VisualStudio.Diagnostics.AspNetHelper.log                     10.05.2026 01:24:13     309
dd_setup_20260510012326_197_Microsoft.MSHtml.log                                                    10.05.2026 01:24:13    1062
dd_setup_20260510012326_196_Microsoft.VisualStudio.Platform.CallHierarchy.log                       10.05.2026 01:24:13   18894
dd_setup_20260510012326_195_Microsoft.VisualStudio.Community.ProductArch.Neutral.log                10.05.2026 01:24:13  132431
dd_setup_20260510012326_194_Microsoft.VisualStudio.Community.Msi.Resources.log                      10.05.2026 01:24:13   84988
dd_setup_20260510012326_193_Microsoft.VisualStudio.Community.Msi.log                                10.05.2026 01:24:13  297216
dd_setup_20260510012326_192_Microsoft.VisualStudio.Community.Shared.Msi.log                         10.05.2026 01:24:12  776058
dd_setup_20260510012326_191_Microsoft.VisualStudio.MinShell.Interop.Msi.log                         10.05.2026 01:24:10 1846972
dd_setup_20260510012326_190_Microsoft.VisualStudio.MinShell.Interop.Shared.Msi.log                  10.05.2026 01:24:08  513462
dd_setup_20260510012326_189_Microsoft.DiagnosticsHub.Runtime.log                                    10.05.2026 01:24:06  103872
dd_setup_20260510012326_188_Microsoft.DiagnosticsHub.Collection.log                                 10.05.2026 01:24:06   14631
dd_setup_20260510012326_187_Microsoft.DiagnosticsHub.Collection.Service.log                         10.05.2026 01:24:06  132042
dd_setup_20260510012326_185_Microsoft.VisualStudio.ScriptedHost.log                                 10.05.2026 01:24:06    4671
dd_setup_20260510012326_184_Microsoft.VisualStudio.ScriptedHost.Targeted.log                        10.05.2026 01:24:06    1056
dd_setup_20260510012326_183_Microsoft.VisualStudio.VirtualTree.log                                  10.05.2026 01:24:06    1200
dd_setup_20260510012326_182_Microsoft.VisualStudio.PerformanceProvider.log                          10.05.2026 01:24:06    1673
dd_setup_20260510012326_181_Microsoft.VisualStudio.GraphModel.log                                   10.05.2026 01:24:06    2352
dd_setup_20260510012326_180_Microsoft.VisualStudio.GraphProvider.log                                10.05.2026 01:24:05   13615
dd_setup_20260510012326_179_Microsoft.VisualStudio.GraphProvider.Auto.log                           10.05.2026 01:24:05    7084
dd_setup_20260510012326_178_Microsoft.VisualStudio.TextMateGrammars.log                             10.05.2026 01:24:05  318581
dd_setup_20260510012326_177_Microsoft.VisualStudio.Platform.Markdown.log                            10.05.2026 01:24:05   34233
dd_setup_20260510012326_176_Microsoft.ServiceHub.Node.log                                           10.05.2026 01:24:05    5103
dd_setup_20260510012326_175_Microsoft.ServiceHub.Managed.log                                        10.05.2026 01:24:05   48738
dd_setup_20260510012326_174_Microsoft.VisualStudio.OpenFolder.VSIX.log                              10.05.2026 01:24:05   94695
dd_setup_20260510012326_173_Microsoft.VisualStudio.FileHandler.Msi.log                              10.05.2026 01:24:05  129324
dd_setup_20260510012326_172_Microsoft.VisualStudio.FileHandler.Msi.log                              10.05.2026 01:24:04  163966
dd_setup_20260510012326_171_Microsoft.VisualStudio.MinShell.Msi.log                                 10.05.2026 01:24:04   80772
dd_setup_20260510012326_170_Microsoft.VisualStudio.MinShell.Shared.Msi.log                          10.05.2026 01:24:04  101674
dd_setup_20260510012326_169_Microsoft.VisualStudio.MinShell.Msi.Resources.log                       10.05.2026 01:24:03   85732
dd_setup_20260510012326_168_Microsoft.VisualStudio.MinShell.Interop.log                             10.05.2026 01:24:03   41507
dd_setup_20260510012326_167_Microsoft.VisualStudio.NgenRunner.log                                   10.05.2026 01:24:02    1605
dd_setup_20260510012326_166_CoreEditorFonts.log                                                     10.05.2026 01:24:02   79396
dd_setup_20260510012326_165_Microsoft.VisualStudio.Log.log                                          10.05.2026 01:24:02   11798
dd_setup_20260510012326_164_Microsoft.VisualStudio.Log.Targeted.log                                 10.05.2026 01:24:02    1146
dd_setup_20260510012326_163_Microsoft.VisualStudio.Log.Resources.log                                10.05.2026 01:24:02     936
dd_setup_20260510012326_162_Microsoft.VisualStudio.Finalizer.log                                    10.05.2026 01:24:02   11253
dd_setup_20260510012326_161_Microsoft.VisualStudio.ErrorList.log                                    10.05.2026 01:24:01   16597
dd_setup_20260510012326_160_Microsoft.VisualStudio.CoreEditor.log                                   10.05.2026 01:24:01   25707
dd_setup_20260510012326_159_Microsoft.VisualStudio.CoreEditor.UserProfiles.log                      10.05.2026 01:24:01    5088
dd_setup_20260510012326_158_Microsoft.VisualStudio.Platform.NavigateTo.log                          10.05.2026 01:24:01    5085
dd_setup_20260510012326_157_Microsoft.VisualStudio.Connected.log                                    10.05.2026 01:24:01   29386
dd_setup_20260510012326_156_Microsoft.VisualStudio.Identity.log                                     10.05.2026 01:24:01  491097
dd_setup_20260510012326_155_Microsoft.Developer.IdentityServiceGS.log                               10.05.2026 01:23:58   16167
dd_setup_20260510012326_154_SQLitePCLRaw.log                                                        10.05.2026 01:23:58    4925
dd_setup_20260510012326_153_SQLitePCLRaw.Targeted.log                                               10.05.2026 01:23:58    1206
dd_setup_20260510012326_152_Microsoft.VisualStudio.Connected.Auto.log                               10.05.2026 01:23:58    3741
dd_setup_20260510012326_151_Microsoft.VisualStudio.Connected.Auto.Resources.log                     10.05.2026 01:23:58    1278
dd_setup_20260510012326_150_Microsoft.VisualStudio.Connected.Resources.log                          10.05.2026 01:23:58     309
dd_setup_20260510012326_149_Microsoft.VisualStudio.VC.Ide.x64.log                                   10.05.2026 01:23:58    1020
dd_setup_20260510012326_148_Microsoft.VisualStudio.Debugger.Script.Msi.log                          10.05.2026 01:23:58 1769018
dd_setup_20260510012326_147_Microsoft.VisualStudio.Debugger.Script.log                              10.05.2026 01:23:56    2802
dd_setup_20260510012326_146_Microsoft.VisualStudio.Debugger.Script.Resources.log                    10.05.2026 01:23:56    1140
dd_setup_20260510012326_145_Microsoft.VisualStudio.Debugger.Script.Remote.log                       10.05.2026 01:23:56    1929
dd_setup_20260510012326_144_Microsoft.VisualStudio.Debugger.Script.Remote.log                       10.05.2026 01:23:56    1917
dd_setup_20260510012326_143_Microsoft.VisualStudio.Debugger.Script.Remote.Resources.log             10.05.2026 01:23:56    1182
dd_setup_20260510012326_142_Microsoft.VisualStudio.Debugger.Script.Remote.Resources.log             10.05.2026 01:23:56    1182
dd_setup_20260510012326_141_Microsoft.VisualStudio.VC.Ide.WinXPlus.log                              10.05.2026 01:23:56   19857
dd_setup_20260510012326_140_Microsoft.VisualStudio.VC.Ide.Dskx.log                                  10.05.2026 01:23:56    4914
dd_setup_20260510012326_139_Microsoft.VisualStudio.VC.Ide.Dskx.Resources.log                        10.05.2026 01:23:56    1623
dd_setup_20260510012326_138_Microsoft.VisualStudio.VC.Ide.Base.log                                  10.05.2026 01:23:56  119658
dd_setup_20260510012326_137_Microsoft.VisualStudio.VC.Ide.LanguageService.log                       10.05.2026 01:23:55   53309
dd_setup_20260510012326_136_Microsoft.VisualStudio.VC.Copilot.Setup.log                             10.05.2026 01:23:55    4227
dd_setup_20260510012326_135_Microsoft.VisualStudio.VC.Ide.VCPkgDatabase.log                         10.05.2026 01:23:55    1164
dd_setup_20260510012326_134_Microsoft.VisualStudio.VC.Ide.ResourceEditor.log                        10.05.2026 01:23:55   11892
dd_setup_20260510012326_133_Microsoft.VisualStudio.VC.Ide.ResourceEditor.Resources.log              10.05.2026 01:23:55    3219
dd_setup_20260510012326_132_Microsoft.VisualStudio.VC.Ide.LanguageService.Dependencies.log          10.05.2026 01:23:55    2199
dd_setup_20260510012326_131_Microsoft.VisualStudio.VC.Ide.Core.log                                  10.05.2026 01:23:55    6327
dd_setup_20260510012326_130_Microsoft.VisualStudio.VisualC.Utilities.log                            10.05.2026 01:23:55    2103
dd_setup_20260510012326_129_Microsoft.VisualStudio.VisualC.Utilities.Resources.log                  10.05.2026 01:23:55     309
dd_setup_20260510012326_128_Microsoft.VisualStudio.VC.Ide.ProjectSystem.log                         10.05.2026 01:23:55   18272
dd_setup_20260510012326_127_Microsoft.VisualStudio.VC.Ide.ProjectSystem.Resources.log               10.05.2026 01:23:55    4350
dd_setup_20260510012326_126_Microsoft.VisualStudio.VC.Ide.Core.VCProjectEngine.log                  10.05.2026 01:23:55    1194
dd_setup_20260510012326_125_Microsoft.VisualStudio.VC.Ide.Core.VCProjectEngine.Resources.log        10.05.2026 01:23:55    1212
dd_setup_20260510012326_124_Microsoft.VisualStudio.VC.Ide.LanguageService.Resources.log             10.05.2026 01:23:54   45036
dd_setup_20260510012326_123_Microsoft.VisualStudio.VC.Llvm.Base.log                                 10.05.2026 01:23:54   78315
dd_setup_20260510012326_122_Microsoft.VisualStudio.VC.Ide.Base.Resources.log                        10.05.2026 01:23:53    3663
dd_setup_20260510012326_121_Microsoft.VisualStudio.Debugger.BrokeredServices.log                    10.05.2026 01:23:53   17449
dd_setup_20260510012326_120_Microsoft.VisualStudio.Debugger.VSCodeDebuggerHost.log                  10.05.2026 01:23:53   21441
dd_setup_20260510012326_119_Microsoft.VisualStudio.Debugger.AzureAttach.log                         10.05.2026 01:23:53    2373
dd_setup_20260510012326_118_Microsoft.VisualStudio.Web.Azure.Common.log                             10.05.2026 01:23:53    9699
dd_setup_20260510012326_117_Microsoft.WebTools.Shared.log                                           10.05.2026 01:23:53  415675
dd_setup_20260510012326_116_Microsoft.WebTools.DotNet.Core.ItemTemplates.log                        10.05.2026 01:23:53    7392
dd_setup_20260510012326_115_Microsoft.VisualStudio.VC.Ide.Debugger.log                              10.05.2026 01:23:53   23592
dd_setup_20260510012326_114_Microsoft.VisualStudio.VC.Ide.Debugger.Concord.log                      10.05.2026 01:23:53    3507
dd_setup_20260510012326_113_Microsoft.VisualStudio.VC.Ide.Debugger.Concord.Resources.log            10.05.2026 01:23:53    1713
dd_setup_20260510012326_112_Microsoft.VisualStudio.VC.Ide.Debugger.Resources.log                    10.05.2026 01:23:53    1857
dd_setup_20260510012326_111_Microsoft.VisualStudio.VC.Ide.Common.log                                10.05.2026 01:23:53   11508
dd_setup_20260510012326_110_Microsoft.VisualStudio.VC.Ide.Common.Resources.log                      10.05.2026 01:23:52    1677
dd_setup_20260510012326_109_Microsoft.VisualStudio.Debugger.CollectionAgents.log                    10.05.2026 01:23:52    2073
dd_setup_20260510012326_108_Microsoft.VisualStudio.Debugger.Parallel.log                            10.05.2026 01:23:52    7208
dd_setup_20260510012326_107_Microsoft.VisualStudio.Debugger.Parallel.Resources.log                  10.05.2026 01:23:52    1182
dd_setup_20260510012326_106_Microsoft.VisualStudio.Debugger.Managed.log                             10.05.2026 01:23:52   43959
dd_setup_20260510012326_105_Microsoft.DiaSymReader.log                                              10.05.2026 01:23:52    1104
dd_setup_20260510012326_104_Microsoft.CodeAnalysis.ExpressionEvaluator.log                          10.05.2026 01:23:52   51786
dd_setup_20260510012326_103_Microsoft.VisualStudio.Debugger.Concord.Managed.log                     10.05.2026 01:23:52   10304
dd_setup_20260510012326_102_Microsoft.VisualStudio.Debugger.Concord.Managed.Resources.log           10.05.2026 01:23:52     309
dd_setup_20260510012326_101_Microsoft.VisualStudio.Debugger.Managed.Resources.log                   10.05.2026 01:23:52    2013
dd_setup_20260510012326_100_Microsoft.VisualStudio.Debugger.TargetComposition.log                   10.05.2026 01:23:52    2202
dd_setup_20260510012326_099_Microsoft.VisualStudio.Debugger.TargetComposition.Remote.log            10.05.2026 01:23:52    2580
dd_setup_20260510012326_098_Microsoft.VisualStudio.Debugger.TargetComposition.Remote.log            10.05.2026 01:23:52    2580
dd_setup_20260510012326_097_Microsoft.VisualStudio.Debugger.Remote.log                              10.05.2026 01:23:52   76719
dd_setup_20260510012326_096_Microsoft.VisualStudio.Debugger.Concord.Remote.log                      10.05.2026 01:23:52   14805
dd_setup_20260510012326_095_Microsoft.VisualStudio.Debugger.Concord.Remote.Resources.log            10.05.2026 01:23:51    1170
dd_setup_20260510012326_094_Microsoft.VisualStudio.Debugger.Remote.log                              10.05.2026 01:23:51   77562
dd_setup_20260510012326_093_Microsoft.VisualStudio.Debugger.Concord.Remote.log                      10.05.2026 01:23:51   13134
dd_setup_20260510012326_092_Microsoft.VisualStudio.Debugger.Concord.Remote.Resources.log            10.05.2026 01:23:51    1170
dd_setup_20260510012326_091_Microsoft.VisualStudio.Debugger.Remote.Resources.log                    10.05.2026 01:23:51    2670
dd_setup_20260510012326_090_Microsoft.VisualStudio.Debugger.Remote.Resources.log                    10.05.2026 01:23:51    3495
dd_setup_20260510012326_089_Microsoft.VisualStudio.Debugger.log                                     10.05.2026 01:23:51   77822
dd_setup_20260510012326_088_Microsoft.VisualStudio.AzureSDK.log                                     10.05.2026 01:23:51    8316
dd_setup_20260510012326_087_Microsoft.VisualStudio.Editors.log                                      10.05.2026 01:23:51   30075
dd_setup_20260510012326_086_Microsoft.VisualStudio.VC.MSVCDis.log                                   10.05.2026 01:23:51     924
dd_setup_20260510012326_085_Microsoft.IntelliTrace.DiagnosticsHub.log                               10.05.2026 01:23:51   14729
dd_setup_20260510012326_084_Microsoft.VisualStudio.MinShell.log                                     10.05.2026 01:23:50   90275
dd_setup_20260510012326_083_Microsoft.VisualStudio.OpenTelemetry.Collector.netfx.log                10.05.2026 01:23:50    1446
dd_setup_20260510012326_082_Microsoft.VisualStudio.OpenTelemetry.ClientExtensions.netfx.log         10.05.2026 01:23:50    4677
dd_setup_20260510012326_081_Microsoft.VisualStudio.Copilot.Contracts.log                            10.05.2026 01:23:50    9663
dd_setup_20260510012326_080_Microsoft.VisualStudio.Licensing.log                                    10.05.2026 01:23:50    2142
dd_setup_20260510012326_079_Microsoft.VisualStudio.IdentityDependencies.log                         10.05.2026 01:23:50   10335
dd_setup_20260510012326_078_Microsoft.VisualStudio.GitHubProtocolHandler.Msi.log                    10.05.2026 01:23:50  101086
dd_setup_20260510012326_077_Microsoft.VisualStudio.VsWebProtocolSelector.Msi.log                    10.05.2026 01:23:50   92780
dd_setup_20260510012326_076_Microsoft.VisualStudio.Extensibility.Container.log                      10.05.2026 01:23:49   46635
dd_setup_20260510012326_075_Microsoft.VisualStudio.LanguageServer.log                               10.05.2026 01:23:49   37933
dd_setup_20260510012326_074_Microsoft.VisualStudio.MefHosting.log                                   10.05.2026 01:23:49    6697
dd_setup_20260510012326_073_Microsoft.VisualStudio.Initializer.log                                  10.05.2026 01:23:49    1289
dd_setup_20260510012326_072_Microsoft.VisualStudio.ExtensionManager.log                             10.05.2026 01:23:49   41128
dd_setup_20260510012326_071_Microsoft.VisualStudio.ExtensionManager.Auto.log                        10.05.2026 01:23:49    4964
dd_setup_20260510012326_070_Microsoft.VisualStudio.Platform.Editor.log                              10.05.2026 01:23:49   85085
dd_setup_20260510012326_069_Microsoft.VisualStudio.MinShell.Targeted.log                            10.05.2026 01:23:48  107187
dd_setup_20260510012326_068_Microsoft.VisualStudio.Devenv.Config.log                                10.05.2026 01:23:48     918
dd_setup_20260510012326_067_Microsoft.VisualStudio.MinShell.Resources.log                           10.05.2026 01:23:48   10477
dd_setup_20260510012326_066_Microsoft.VisualStudio.UIInternal.Guide.log                             10.05.2026 01:23:48  194262
dd_setup_20260510012326_065_Microsoft.VisualStudio.UIInternal.log                                   10.05.2026 01:23:48  116629
dd_setup_20260510012326_064_Microsoft.VisualStudio.UIInternal.Resources.log                         10.05.2026 01:23:47    1182
dd_setup_20260510012326_063_Microsoft.VisualStudio.CoreDotNet.log                                   10.05.2026 01:23:47   62586
dd_setup_20260510012326_062_Microsoft.VisualStudio.MinShell.Auto.log                                10.05.2026 01:23:47   36514
dd_setup_20260510012326_061_Microsoft.VisualStudio.MinShell.Auto.Resources.log                      10.05.2026 01:23:47    4824
dd_setup_20260510012326_060_Microsoft.VisualStudio.Debugger.Concord.log                             10.05.2026 01:23:47   22481
dd_setup_20260510012326_059_Microsoft.VisualStudio.Debugger.Concord.Resources.log                   10.05.2026 01:23:47    2157
dd_setup_20260510012326_058_Microsoft.VisualStudio.Debugger.Resources.log                           10.05.2026 01:23:47    5323
dd_setup_20260510012326_057_Microsoft.DiaSymReader.PortablePdb.log                                  10.05.2026 01:23:47    1176
dd_setup_20260510012326_056_Microsoft.VisualStudio.PerfLib.log                                      10.05.2026 01:23:47    8469
dd_setup_20260510012326_055_Microsoft.VisualStudio.Debugger.Package.DiagHub.Client.log              10.05.2026 01:23:47    1110
dd_setup_20260510012326_054_Microsoft.VisualStudio.Debugger.Remote.DiagnosticsHub.Client.log        10.05.2026 01:23:47    1152
dd_setup_20260510012326_053_Microsoft.VisualStudio.Debugger.Remote.DiagnosticsHub.Client.log        10.05.2026 01:23:47    1152
dd_setup_20260510012326_052_Microsoft.VisualStudio.TextTemplating.MSBuild.log                       10.05.2026 01:23:47   13308
dd_setup_20260510012326_051_Microsoft.VisualStudio.TextTemplating.Integration.log                   10.05.2026 01:23:47   23722
dd_setup_20260510012326_050_Microsoft.VisualStudio.TextTemplating.Core.log                          10.05.2026 01:23:47   17887
dd_setup_20260510012326_049_Microsoft.CodeAnalysis.VisualStudio.Setup.log                           10.05.2026 01:23:47  711239
dd_setup_20260510012326_048_Microsoft.VisualStudio.TextTemplating.Integration.Resources.log         10.05.2026 01:23:45     586
dd_setup_20260510012326_047_Microsoft.VisualStudio.TestTools.DynamicCodeCoverage.log                10.05.2026 01:23:45   46134
dd_setup_20260510012326_046_Microsoft.VisualStudio.InstrumentationEngine.log                        10.05.2026 01:23:45    2451
dd_setup_20260510012326_045_Microsoft.CodeCoverage.Console.Targeted.log                             10.05.2026 01:23:45   74943
dd_setup_20260510012326_044_Microsoft.VisualStudio.TestTools.TestPlatform.V1.CLI.log                10.05.2026 01:23:45    6918
dd_setup_20260510012326_043_Microsoft.VisualStudio.TestTools.TestPlatform.V2.CLI.log                10.05.2026 01:23:45  414069
dd_setup_20260510012326_042_Microsoft.VisualStudio.VC.UnitTest.Desktop.Build.Core.log               10.05.2026 01:23:44   13707
dd_setup_20260510012326_041_Microsoft.VisualStudio.TestTools.TestPlatform.V1.CPP.log                10.05.2026 01:23:44    1416
dd_setup_20260510012326_040_Microsoft.VisualCpp.Tools.Common.Utils.log                              10.05.2026 01:23:44    4581
dd_setup_20260510012326_039_Microsoft.VisualCpp.Tools.Common.Utils.Resources.log                    10.05.2026 01:23:44    1611
dd_setup_20260510012326_038_Microsoft.VisualCpp.Redist.14.Latest.log                                10.05.2026 01:23:44   12728
dd_setup_20260510012326_037_Microsoft.VisualCpp.Redist.14.Latest.log                                10.05.2026 01:23:43   15214
dd_setup_20260510012326_037_Microsoft.VisualCpp.Redist.14.Latest_001_vcRuntimeAdditional_x86.log    10.05.2026 01:23:43  146714
dd_setup_20260510012326_037_Microsoft.VisualCpp.Redist.14.Latest_000_vcRuntimeMinimum_x86.log       10.05.2026 01:23:42  134916
dd_setup_20260510012326_036_Microsoft.VisualCpp.Redist.14.log                                       10.05.2026 01:23:41   12644
dd_setup_20260510012326_035_Microsoft.VisualCpp.Redist.14.log                                       10.05.2026 01:23:40   15130
dd_setup_20260510012326_035_Microsoft.VisualCpp.Redist.14_001_vcRuntimeAdditional_x86.log           10.05.2026 01:23:40  146686
dd_setup_20260510012326_035_Microsoft.VisualCpp.Redist.14_000_vcRuntimeMinimum_x86.log              10.05.2026 01:23:40  134888
dd_setup_20260510012326_034_Microsoft.VisualCpp.Servicing.Redist.log                                10.05.2026 01:23:38    3681
dd_setup_20260510012326_033_Microsoft.VisualStudio.VC.vcvars.log                                    10.05.2026 01:23:38    1731
dd_setup_20260510012326_032_Microsoft.VS.VC.vcvars.x86.Shortcuts.log                                10.05.2026 01:23:38     309
dd_setup_20260510012326_031_Microsoft.VS.VC.vcvars.x64.Shortcuts.log                                10.05.2026 01:23:38     309
dd_setup_20260510012326_030_Microsoft.Windows.UniversalCRT.Redistributable.Msi.log                  10.05.2026 01:23:38  671890
dd_setup_20260510012326_029_Microsoft.VisualStudio.VC.MSBuild.v170.x86.v143.log                     10.05.2026 01:23:36    2163
dd_setup_20260510012326_028_Microsoft.VisualStudio.VC.MSBuild.v170.X86.log                          10.05.2026 01:23:36    3591
dd_setup_20260510012326_027_Microsoft.VisualStudio.VC.MSBuild.v170.X64.v143.log                     10.05.2026 01:23:36    2139
dd_setup_20260510012326_026_Microsoft.VisualStudio.VC.MSBuild.v170.X64.log                          10.05.2026 01:23:36    3543
dd_setup_20260510012326_025_Microsoft.VisualStudio.VC.MSBuild.v170.ARM.v143.log                     10.05.2026 01:23:36    2139
dd_setup_20260510012326_024_Microsoft.VisualStudio.VC.MSBuild.v170.ARM.log                          10.05.2026 01:23:36    3543
dd_setup_20260510012326_023_Microsoft.VisualStudio.VC.MSBuild.v170.Base.log                         10.05.2026 01:23:36   82602
dd_setup_20260510012326_022_Microsoft.VisualStudio.VC.MSBuild.v170.Base.Resources.log               10.05.2026 01:23:36   38712
dd_setup_20260510012326_021_Microsoft.VisualStudio.Setup.WMIProvider.log                            10.05.2026 01:23:35  146514
dd_setup_20260510012326_020_Microsoft.VisualStudio.Setup.Configuration.Interop.log                  10.05.2026 01:23:34    1272
dd_setup_20260510012326_019_Microsoft.VisualStudio.Setup.Configuration.log                          10.05.2026 01:23:34   99674
dd_setup_20260510012326_018_Microsoft.VisualStudio.VsDevCmd.Ext.NetFxSdk.log                        10.05.2026 01:23:34    1002
dd_setup_20260510012326_017_Microsoft.VisualStudio.VsDevCmd.Core.WinSdk.log                         10.05.2026 01:23:34     996
dd_setup_20260510012326_016_Microsoft.VisualStudio.VsDevCmd.Core.DotNet.log                         10.05.2026 01:23:34     996
dd_setup_20260510012326_015_Microsoft.VisualStudio.VC.DevCmd.log                                    10.05.2026 01:23:34    9594
dd_setup_20260510012326_014_Microsoft.VisualStudio.VC.DevCmd.Resources.log                          10.05.2026 01:23:34    1140
dd_setup_20260510012326_013_Microsoft.VisualStudio.BuildTools.Resources.log                         10.05.2026 01:23:34    1044
dd_setup_20260510012326_012_Microsoft.VisualStudio.Net.Eula.Resources.log                           10.05.2026 01:23:34     990
dd_setup_20260510012326_011_Microsoft.Build.Dependencies.log                                        10.05.2026 01:23:34  435036
dd_setup_20260510012326_010_Microsoft.Build.FileTracker.Msi.log                                     10.05.2026 01:23:33  250678
dd_setup_20260510012326_009_Microsoft.PythonTools.BuildCore.Vsix.log                                10.05.2026 01:23:32   15561
dd_setup_20260510012326_008_Microsoft.NuGet.Build.Tasks.Setup.log                                   10.05.2026 01:23:32    6384
dd_setup_20260510012326_007_Microsoft.CodeAnalysis.Compilers.log                                    10.05.2026 01:23:32  106164
dd_setup_20260510012326_006_Microsoft.VisualStudio.NativeImageSupport.log                           10.05.2026 01:23:32    1497
dd_setup_20260510012326_005_Microsoft.Build.log                                                     10.05.2026 01:23:32  263505
dd_setup_20260510012326_004_Microsoft.VisualStudio.NuGet.BuildTools.log                             10.05.2026 01:23:31  224253
dd_setup_20260510012326_003_Microsoft.Build.UnGAC.log                                               10.05.2026 01:23:31    1491
dd_setup_20260510012326_002_Microsoft.VisualStudio.VC.Icons.log                                     10.05.2026 01:23:31     900
dd_setup_20260510012326_000_TestMSI.log                                                             10.05.2026 01:23:29   63154
dd_setup_20260510012326_errors.log                                                                  10.05.2026 01:23:26       0
dd_setup_20260510012322.log                                                                         10.05.2026 01:23:23    7846
dd_setup_20260510012322_errors.log                                                                  10.05.2026 01:23:22       0
dd_setup_20260510012225.log                                                                         10.05.2026 01:22:26    7846
dd_setup_20260510012225_errors.log                                                                  10.05.2026 01:22:25       0
dd_setup_20260510012041.log                                                                         10.05.2026 01:20:42    7846
dd_setup_20260510012041_errors.log                                                                  10.05.2026 01:20:41       0
dd_bootstrapper_20260510011558.log                                                                  10.05.2026 01:16:05    5490
dd_installer_20260510011601.log                                                                     10.05.2026 01:16:05   18935
dd_setup_20260510011602.log                                                                         10.05.2026 01:16:04    8171
dd_setup_20260510011602_errors.log                                                                  10.05.2026 01:16:02       0
dd_bootstrapper_20260510010136.log                                                                  10.05.2026 01:03:35    5746
dd_installer_20260510010137.log                                                                     10.05.2026 01:03:35   45284
dd_installer_elevated_20260510010141.log                                                            10.05.2026 01:03:35 5214227
dd_setup_20260510010334.log                                                                         10.05.2026 01:03:35    8254
dd_setup_20260510010334_errors.log                                                                  10.05.2026 01:03:34       0
dd_setup_20260510010142.log                                                                         10.05.2026 01:03:34 4582349
dd_setup_20260510010142_238_Win11SDK_10.0.22621.log                                                 10.05.2026 01:03:32     719
dd_setup_20260510010142_237_Microsoft.VisualStudio.VC.Ide.Linux.ConnectionManager.log               10.05.2026 01:02:22   17991
dd_setup_20260510010142_236_Microsoft.VisualStudio.VC.Ide.Linux.Shared.log                          10.05.2026 01:02:22    1182
dd_setup_20260510010142_235_Microsoft.VisualStudio.VC.Ide.Linux.Shared.Resources.log                10.05.2026 01:02:22    1260
dd_setup_20260510010142_234_Microsoft.VisualStudio.VC.Ide.Linux.ConnectionManager.Resources.log     10.05.2026 01:02:22   11403
dd_setup_20260510010142_233_Microsoft.VisualStudio.TestTools.TestWIExtension.log                    10.05.2026 01:02:22    3984
dd_setup_20260510010142_232_Microsoft.VisualStudio.TestTools.TestPlatform.IDE.log                   10.05.2026 01:02:22 1056826
dd_setup_20260510010142_231_Microsoft.VisualStudio.VC.Templates.UnitTest.log                        10.05.2026 01:02:20    8256
dd_setup_20260510010142_230_Microsoft.VisualStudio.VC.Templates.UnitTest.Resources.log              10.05.2026 01:02:20    4968
dd_setup_20260510010142_229_Microsoft.VisualStudio.VC.Templates.Desktop.log                         10.05.2026 01:02:20   18816
dd_setup_20260510010142_228_Microsoft.VisualStudio.VC.Ide.Pro.log                                   10.05.2026 01:02:20     309
dd_setup_20260510010142_227_Microsoft.VisualStudio.VC.Ide.Pro.Resources.log                         10.05.2026 01:02:20   15780
dd_setup_20260510010142_226_Microsoft.VisualStudio.VC.Templates.General.log                         10.05.2026 01:02:20   45459
dd_setup_20260510010142_225_Microsoft.VisualStudio.VC.Templates.General.Resources.log               10.05.2026 01:02:20   13692
dd_setup_20260510010142_224_Microsoft.VisualStudio.VC.Items.Pro.log                                 10.05.2026 01:02:20    4098
dd_setup_20260510010142_223_Microsoft.VisualStudio.VC.Ide.MDD.log                                   10.05.2026 01:02:20   21816
dd_setup_20260510010142_222_Microsoft.VisualStudio.CodeSense.Community.log                          10.05.2026 01:02:20    7282
dd_setup_20260510010142_221_Microsoft.VisualStudio.TestTools.TeamFoundationClient.log               10.05.2026 01:02:20   39528
dd_setup_20260510010142_220_Microsoft.VisualStudio.AppResponsiveness.log                            10.05.2026 01:02:20   51195
dd_setup_20260510010142_219_Microsoft.VisualStudio.AppResponsiveness.Targeted.log                   10.05.2026 01:02:20    1392
dd_setup_20260510010142_218_Microsoft.VisualStudio.AppResponsiveness.Resources.log                  10.05.2026 01:02:20    3786
dd_setup_20260510010142_217_Microsoft.VisualStudio.ClientDiagnostics.log                            10.05.2026 01:02:19   11898
dd_setup_20260510010142_216_Microsoft.VisualStudio.ClientDiagnostics.Targeted.log                   10.05.2026 01:02:19    2139
dd_setup_20260510010142_215_Microsoft.VisualStudio.ClientDiagnostics.Resources.log                  10.05.2026 01:02:19    1452
dd_setup_20260510010142_214_Microsoft.VisualStudio.ProjectSystem.Full.log                           10.05.2026 01:02:19     594
dd_setup_20260510010142_213_Microsoft.VisualStudio.LiveShareApi.log                                 10.05.2026 01:02:19    1260
dd_setup_20260510010142_212_Microsoft.VisualStudio.ProjectSystem.Query.log                          10.05.2026 01:02:19   31131
dd_setup_20260510010142_211_Microsoft.VisualStudio.ProjectSystem.log                                10.05.2026 01:02:19   49894
dd_setup_20260510010142_210_Microsoft.VisualStudio.Community.x86.log                                10.05.2026 01:02:19    3567
dd_setup_20260510010142_209_Microsoft.VisualStudio.Community.x64.log                                10.05.2026 01:02:19    3393
dd_setup_20260510010142_208_Microsoft.VisualStudio.Community.VB.Targeted.log                        10.05.2026 01:02:19    2667
dd_setup_20260510010142_207_Microsoft.VisualStudio.Community.VB.Neutral.log                         10.05.2026 01:02:18   10062
dd_setup_20260510010142_206_Microsoft.VisualStudio.Community.CSharp.Targeted.log                    10.05.2026 01:02:18    4347
dd_setup_20260510010142_205_Microsoft.VisualStudio.Community.CSharp.Neutral.log                     10.05.2026 01:02:18   21120
dd_setup_20260510010142_204_Microsoft.VisualStudio.Community.ProductArch.TargetedExtra.log          10.05.2026 01:02:18    4122
dd_setup_20260510010142_203_Microsoft.VisualStudio.Community.ProductArch.Targeted.log               10.05.2026 01:02:18   28655
dd_setup_20260510010142_202_Microsoft.VisualStudio.Community.ProductArch.NeutralExtra.log           10.05.2026 01:02:18   13500
dd_setup_20260510010142_201_Microsoft.IntelliTrace.CollectorCab.log                                 10.05.2026 01:02:18    2169
dd_setup_20260510010142_200_Microsoft.VisualStudio.Community.VB.Resources.Targeted.log              10.05.2026 01:02:18    2190
dd_setup_20260510010142_199_Microsoft.VisualStudio.Community.VB.Resources.Neutral.log               10.05.2026 01:02:18  314136
dd_setup_20260510010142_198_Microsoft.VisualStudio.Community.CSharp.Resources.Targeted.log          10.05.2026 01:02:18     972
dd_setup_20260510010142_197_Microsoft.VisualStudio.Community.CSharp.Resources.Neutral.log           10.05.2026 01:02:18   56763
dd_setup_20260510010142_196_Microsoft.VisualStudio.Community.ProductArch.Resources.Targeted.log     10.05.2026 01:02:17    9147
dd_setup_20260510010142_195_Microsoft.VisualStudio.Community.ProductArch.Resources.NeutralExtra.log 10.05.2026 01:02:17   33943
dd_setup_20260510010142_194_Microsoft.VisualStudio.Community.ProductArch.Resources.Neutral.log      10.05.2026 01:02:17   46611
dd_setup_20260510010142_193_Microsoft.VisualStudio.WebSiteProject.DTE.log                           10.05.2026 01:02:17    2616
dd_setup_20260510010142_192_Microsoft.VisualStudio.Diagnostics.AspNetHelper.log                     10.05.2026 01:02:17     309
dd_setup_20260510010142_191_Microsoft.MSHtml.log                                                    10.05.2026 01:02:17    1062
dd_setup_20260510010142_190_Microsoft.VisualStudio.Platform.CallHierarchy.log                       10.05.2026 01:02:17   18894
dd_setup_20260510010142_189_Microsoft.VisualStudio.Community.ProductArch.Neutral.log                10.05.2026 01:02:17  132431
dd_setup_20260510010142_188_Microsoft.VisualStudio.Community.Msi.Resources.log                      10.05.2026 01:02:17   88296
dd_setup_20260510010142_187_Microsoft.VisualStudio.Community.Msi.log                                10.05.2026 01:02:16  292860
dd_setup_20260510010142_186_Microsoft.VisualStudio.Community.Shared.Msi.log                         10.05.2026 01:02:16  687658
dd_setup_20260510010142_185_Microsoft.VisualStudio.MinShell.Interop.Msi.log                         10.05.2026 01:02:15 1807824
dd_setup_20260510010142_184_Microsoft.VisualStudio.MinShell.Interop.Shared.Msi.log                  10.05.2026 01:02:12  456590
dd_setup_20260510010142_183_Microsoft.DiagnosticsHub.Runtime.log                                    10.05.2026 01:02:11  103872
dd_setup_20260510010142_182_Microsoft.DiagnosticsHub.Collection.log                                 10.05.2026 01:02:11   14631
dd_setup_20260510010142_181_Microsoft.DiagnosticsHub.Collection.Service.log                         10.05.2026 01:02:10  129034
dd_setup_20260510010142_180_Microsoft.VisualStudio.ScriptedHost.log                                 10.05.2026 01:02:10    4671
dd_setup_20260510010142_179_Microsoft.VisualStudio.ScriptedHost.Targeted.log                        10.05.2026 01:02:10    1056
dd_setup_20260510010142_178_Microsoft.VisualStudio.VirtualTree.log                                  10.05.2026 01:02:10    1200
dd_setup_20260510010142_177_Microsoft.VisualStudio.PerformanceProvider.log                          10.05.2026 01:02:10    1673
dd_setup_20260510010142_176_Microsoft.VisualStudio.GraphModel.log                                   10.05.2026 01:02:10    2352
dd_setup_20260510010142_175_Microsoft.VisualStudio.GraphProvider.log                                10.05.2026 01:02:10   13615
dd_setup_20260510010142_174_Microsoft.VisualStudio.GraphProvider.Auto.log                           10.05.2026 01:02:10    7084
dd_setup_20260510010142_173_Microsoft.VisualStudio.TextMateGrammars.log                             10.05.2026 01:02:10  318581
dd_setup_20260510010142_172_Microsoft.VisualStudio.Platform.Markdown.log                            10.05.2026 01:02:10   34233
dd_setup_20260510010142_171_Microsoft.ServiceHub.Node.log                                           10.05.2026 01:02:10    5103
dd_setup_20260510010142_170_Microsoft.ServiceHub.Managed.log                                        10.05.2026 01:02:10   48738
dd_setup_20260510010142_169_Microsoft.VisualStudio.OpenFolder.VSIX.log                              10.05.2026 01:02:09   94695
dd_setup_20260510010142_168_Microsoft.VisualStudio.FileHandler.Msi.log                              10.05.2026 01:02:09  132248
dd_setup_20260510010142_167_Microsoft.VisualStudio.FileHandler.Msi.log                              10.05.2026 01:02:09  166470
dd_setup_20260510010142_166_Microsoft.VisualStudio.MinShell.Msi.log                                 10.05.2026 01:02:08   83328
dd_setup_20260510010142_165_Microsoft.VisualStudio.MinShell.Shared.Msi.log                          10.05.2026 01:02:08  104142
dd_setup_20260510010142_164_Microsoft.VisualStudio.MinShell.Msi.Resources.log                       10.05.2026 01:02:08   88330
dd_setup_20260510010142_163_Microsoft.VisualStudio.MinShell.Interop.log                             10.05.2026 01:02:07   41507
dd_setup_20260510010142_162_Microsoft.VisualStudio.NgenRunner.log                                   10.05.2026 01:02:07    1605
dd_setup_20260510010142_161_Microsoft.VisualStudio.Log.log                                          10.05.2026 01:02:07   11798
dd_setup_20260510010142_160_Microsoft.VisualStudio.Log.Targeted.log                                 10.05.2026 01:02:07    1146
dd_setup_20260510010142_159_Microsoft.VisualStudio.Log.Resources.log                                10.05.2026 01:02:07     936
dd_setup_20260510010142_158_Microsoft.VisualStudio.Finalizer.log                                    10.05.2026 01:02:07   11253
dd_setup_20260510010142_157_Microsoft.VisualStudio.ErrorList.log                                    10.05.2026 01:02:07   16597
dd_setup_20260510010142_156_Microsoft.VisualStudio.CoreEditor.log                                   10.05.2026 01:02:07   25707
dd_setup_20260510010142_155_Microsoft.VisualStudio.CoreEditor.UserProfiles.log                      10.05.2026 01:02:07    5088
dd_setup_20260510010142_154_Microsoft.VisualStudio.Platform.NavigateTo.log                          10.05.2026 01:02:07    5085
dd_setup_20260510010142_153_Microsoft.VisualStudio.Connected.log                                    10.05.2026 01:02:07   29386
dd_setup_20260510010142_152_Microsoft.VisualStudio.Identity.log                                     10.05.2026 01:02:06  491097
dd_setup_20260510010142_151_Microsoft.Developer.IdentityServiceGS.log                               10.05.2026 01:02:06   16167
dd_setup_20260510010142_150_SQLitePCLRaw.log                                                        10.05.2026 01:02:06    4925
dd_setup_20260510010142_149_SQLitePCLRaw.Targeted.log                                               10.05.2026 01:02:06    1206
dd_setup_20260510010142_148_Microsoft.VisualStudio.Connected.Auto.log                               10.05.2026 01:02:06    3741
dd_setup_20260510010142_147_Microsoft.VisualStudio.Connected.Auto.Resources.log                     10.05.2026 01:02:06    1278
dd_setup_20260510010142_146_Microsoft.VisualStudio.Connected.Resources.log                          10.05.2026 01:02:06     309
dd_setup_20260510010142_145_Microsoft.VisualStudio.VC.Ide.x64.log                                   10.05.2026 01:02:06    1020
dd_setup_20260510010142_144_Microsoft.VisualStudio.Debugger.Script.Msi.log                          10.05.2026 01:02:05 1700514
dd_setup_20260510010142_143_Microsoft.VisualStudio.Debugger.Script.log                              10.05.2026 01:02:03    2802
dd_setup_20260510010142_142_Microsoft.VisualStudio.Debugger.Script.Resources.log                    10.05.2026 01:02:03    1140
dd_setup_20260510010142_141_Microsoft.VisualStudio.Debugger.Script.Remote.log                       10.05.2026 01:02:03    1929
dd_setup_20260510010142_140_Microsoft.VisualStudio.Debugger.Script.Remote.log                       10.05.2026 01:02:03    1917
dd_setup_20260510010142_139_Microsoft.VisualStudio.Debugger.Script.Remote.Resources.log             10.05.2026 01:02:03    1182
dd_setup_20260510010142_138_Microsoft.VisualStudio.Debugger.Script.Remote.Resources.log             10.05.2026 01:02:03    1182
dd_setup_20260510010142_137_Microsoft.VisualStudio.VC.Ide.WinXPlus.log                              10.05.2026 01:02:03   19857
dd_setup_20260510010142_136_Microsoft.VisualStudio.VC.Ide.Dskx.log                                  10.05.2026 01:02:03    4914
dd_setup_20260510010142_135_Microsoft.VisualStudio.VC.Ide.Dskx.Resources.log                        10.05.2026 01:02:03    1623
dd_setup_20260510010142_134_Microsoft.VisualStudio.VC.Ide.Base.log                                  10.05.2026 01:02:03  119658
dd_setup_20260510010142_133_Microsoft.VisualStudio.VC.Ide.LanguageService.log                       10.05.2026 01:02:03   53309
dd_setup_20260510010142_132_Microsoft.VisualStudio.VC.Copilot.Setup.log                             10.05.2026 01:02:02    4227
dd_setup_20260510010142_131_Microsoft.VisualStudio.VC.Ide.VCPkgDatabase.log                         10.05.2026 01:02:02    1164
dd_setup_20260510010142_130_Microsoft.VisualStudio.VC.Ide.ResourceEditor.log                        10.05.2026 01:02:02   11892
dd_setup_20260510010142_129_Microsoft.VisualStudio.VC.Ide.ResourceEditor.Resources.log              10.05.2026 01:02:02    3219
dd_setup_20260510010142_128_Microsoft.VisualStudio.VC.Ide.LanguageService.Dependencies.log          10.05.2026 01:02:02    2199
dd_setup_20260510010142_127_Microsoft.VisualStudio.VC.Ide.Core.log                                  10.05.2026 01:02:02    6327
dd_setup_20260510010142_126_Microsoft.VisualStudio.VisualC.Utilities.log                            10.05.2026 01:02:02    2103
dd_setup_20260510010142_125_Microsoft.VisualStudio.VisualC.Utilities.Resources.log                  10.05.2026 01:02:02     309
dd_setup_20260510010142_124_Microsoft.VisualStudio.VC.Ide.ProjectSystem.log                         10.05.2026 01:02:02   18272
dd_setup_20260510010142_123_Microsoft.VisualStudio.VC.Ide.ProjectSystem.Resources.log               10.05.2026 01:02:02    4350
dd_setup_20260510010142_122_Microsoft.VisualStudio.VC.Ide.Core.VCProjectEngine.log                  10.05.2026 01:02:02    1194
dd_setup_20260510010142_121_Microsoft.VisualStudio.VC.Ide.Core.VCProjectEngine.Resources.log        10.05.2026 01:02:02    1212
dd_setup_20260510010142_120_Microsoft.VisualStudio.VC.Ide.LanguageService.Resources.log             10.05.2026 01:02:02   45036
dd_setup_20260510010142_119_Microsoft.VisualStudio.VC.Llvm.Base.log                                 10.05.2026 01:02:02   78315
dd_setup_20260510010142_118_Microsoft.VisualStudio.VC.Ide.Base.Resources.log                        10.05.2026 01:02:01    3663
dd_setup_20260510010142_117_Microsoft.VisualStudio.Debugger.BrokeredServices.log                    10.05.2026 01:02:01   17449
dd_setup_20260510010142_116_Microsoft.VisualStudio.Debugger.VSCodeDebuggerHost.log                  10.05.2026 01:02:00   21441
dd_setup_20260510010142_115_Microsoft.VisualStudio.Debugger.AzureAttach.log                         10.05.2026 01:02:00    2373
dd_setup_20260510010142_114_Microsoft.VisualStudio.Web.Azure.Common.log                             10.05.2026 01:02:00    9699
dd_setup_20260510010142_113_Microsoft.WebTools.Shared.log                                           10.05.2026 01:02:00  415675
dd_setup_20260510010142_112_Microsoft.WebTools.DotNet.Core.ItemTemplates.log                        10.05.2026 01:02:00    7392
dd_setup_20260510010142_111_Microsoft.VisualStudio.VC.Ide.Debugger.log                              10.05.2026 01:01:59   23592
dd_setup_20260510010142_110_Microsoft.VisualStudio.VC.Ide.Debugger.Concord.log                      10.05.2026 01:01:59    3507
dd_setup_20260510010142_109_Microsoft.VisualStudio.VC.Ide.Debugger.Concord.Resources.log            10.05.2026 01:01:59    1713
dd_setup_20260510010142_108_Microsoft.VisualStudio.VC.Ide.Debugger.Resources.log                    10.05.2026 01:01:59    1857
dd_setup_20260510010142_107_Microsoft.VisualStudio.VC.Ide.Common.log                                10.05.2026 01:01:59   11508
dd_setup_20260510010142_106_Microsoft.VisualStudio.VC.Ide.Common.Resources.log                      10.05.2026 01:01:59    1677
dd_setup_20260510010142_105_Microsoft.VisualStudio.Debugger.CollectionAgents.log                    10.05.2026 01:01:59    2073
dd_setup_20260510010142_104_Microsoft.VisualStudio.Debugger.Parallel.log                            10.05.2026 01:01:59    7208
dd_setup_20260510010142_103_Microsoft.VisualStudio.Debugger.Parallel.Resources.log                  10.05.2026 01:01:59    1182
dd_setup_20260510010142_102_Microsoft.VisualStudio.Debugger.Managed.log                             10.05.2026 01:01:59   43959
dd_setup_20260510010142_101_Microsoft.DiaSymReader.log                                              10.05.2026 01:01:59    1104
dd_setup_20260510010142_100_Microsoft.CodeAnalysis.ExpressionEvaluator.log                          10.05.2026 01:01:59   51786
dd_setup_20260510010142_099_Microsoft.VisualStudio.Debugger.Concord.Managed.log                     10.05.2026 01:01:59   10304
dd_setup_20260510010142_098_Microsoft.VisualStudio.Debugger.Concord.Managed.Resources.log           10.05.2026 01:01:59     309
dd_setup_20260510010142_097_Microsoft.VisualStudio.Debugger.Managed.Resources.log                   10.05.2026 01:01:59    2013
dd_setup_20260510010142_096_Microsoft.VisualStudio.Debugger.TargetComposition.log                   10.05.2026 01:01:59    2202
dd_setup_20260510010142_095_Microsoft.VisualStudio.Debugger.TargetComposition.Remote.log            10.05.2026 01:01:59    2580
dd_setup_20260510010142_094_Microsoft.VisualStudio.Debugger.TargetComposition.Remote.log            10.05.2026 01:01:59    2580
dd_setup_20260510010142_093_Microsoft.VisualStudio.Debugger.Remote.log                              10.05.2026 01:01:59   76719
dd_setup_20260510010142_092_Microsoft.VisualStudio.Debugger.Concord.Remote.log                      10.05.2026 01:01:58   14805
dd_setup_20260510010142_091_Microsoft.VisualStudio.Debugger.Concord.Remote.Resources.log            10.05.2026 01:01:58    1170
dd_setup_20260510010142_090_Microsoft.VisualStudio.Debugger.Remote.log                              10.05.2026 01:01:58   77562
dd_setup_20260510010142_089_Microsoft.VisualStudio.Debugger.Concord.Remote.log                      10.05.2026 01:01:58   13134
dd_setup_20260510010142_088_Microsoft.VisualStudio.Debugger.Concord.Remote.Resources.log            10.05.2026 01:01:58    1170
dd_setup_20260510010142_087_Microsoft.VisualStudio.Debugger.Remote.Resources.log                    10.05.2026 01:01:58    2670
dd_setup_20260510010142_086_Microsoft.VisualStudio.Debugger.Remote.Resources.log                    10.05.2026 01:01:58    3495
dd_setup_20260510010142_085_Microsoft.VisualStudio.Debugger.log                                     10.05.2026 01:01:58   77822
dd_setup_20260510010142_084_Microsoft.VisualStudio.AzureSDK.log                                     10.05.2026 01:01:58    8316
dd_setup_20260510010142_083_Microsoft.VisualStudio.Editors.log                                      10.05.2026 01:01:58   30075
dd_setup_20260510010142_082_Microsoft.VisualStudio.VC.MSVCDis.log                                   10.05.2026 01:01:58     924
dd_setup_20260510010142_081_Microsoft.IntelliTrace.DiagnosticsHub.log                               10.05.2026 01:01:58   14729
dd_setup_20260510010142_080_Microsoft.VisualStudio.MinShell.log                                     10.05.2026 01:01:57   90275
dd_setup_20260510010142_079_Microsoft.VisualStudio.OpenTelemetry.Collector.netfx.log                10.05.2026 01:01:57    1446
dd_setup_20260510010142_078_Microsoft.VisualStudio.OpenTelemetry.ClientExtensions.netfx.log         10.05.2026 01:01:57    4677
dd_setup_20260510010142_077_Microsoft.VisualStudio.Copilot.Contracts.log                            10.05.2026 01:01:57    9663
dd_setup_20260510010142_076_Microsoft.VisualStudio.Licensing.log                                    10.05.2026 01:01:57    2142
dd_setup_20260510010142_075_Microsoft.VisualStudio.IdentityDependencies.log                         10.05.2026 01:01:57   10335
dd_setup_20260510010142_074_Microsoft.VisualStudio.GitHubProtocolHandler.Msi.log                    10.05.2026 01:01:57   98348
dd_setup_20260510010142_073_Microsoft.VisualStudio.VsWebProtocolSelector.Msi.log                    10.05.2026 01:01:56   93428
dd_setup_20260510010142_072_Microsoft.VisualStudio.Extensibility.Container.log                      10.05.2026 01:01:56   46635
dd_setup_20260510010142_071_Microsoft.VisualStudio.LanguageServer.log                               10.05.2026 01:01:56   37933
dd_setup_20260510010142_070_Microsoft.VisualStudio.MefHosting.log                                   10.05.2026 01:01:56    6697
dd_setup_20260510010142_069_Microsoft.VisualStudio.Initializer.log                                  10.05.2026 01:01:56    1326
dd_setup_20260510010142_068_Microsoft.VisualStudio.ExtensionManager.log                             10.05.2026 01:01:55   41128
dd_setup_20260510010142_067_Microsoft.VisualStudio.ExtensionManager.Auto.log                        10.05.2026 01:01:55    4964
dd_setup_20260510010142_066_Microsoft.VisualStudio.Platform.Editor.log                              10.05.2026 01:01:55   85085
dd_setup_20260510010142_065_Microsoft.VisualStudio.MinShell.Targeted.log                            10.05.2026 01:01:55  107187
dd_setup_20260510010142_064_Microsoft.VisualStudio.Devenv.Config.log                                10.05.2026 01:01:55     918
dd_setup_20260510010142_063_Microsoft.VisualStudio.MinShell.Resources.log                           10.05.2026 01:01:55   10477
dd_setup_20260510010142_062_Microsoft.VisualStudio.UIInternal.Guide.log                             10.05.2026 01:01:55  194262
dd_setup_20260510010142_061_Microsoft.VisualStudio.UIInternal.log                                   10.05.2026 01:01:54  116629
dd_setup_20260510010142_060_Microsoft.VisualStudio.UIInternal.Resources.log                         10.05.2026 01:01:54    1182
dd_setup_20260510010142_059_Microsoft.VisualStudio.CoreDotNet.log                                   10.05.2026 01:01:54   62586
dd_setup_20260510010142_058_Microsoft.VisualStudio.MinShell.Auto.log                                10.05.2026 01:01:54   36514
dd_setup_20260510010142_057_Microsoft.VisualStudio.MinShell.Auto.Resources.log                      10.05.2026 01:01:54    4824
dd_setup_20260510010142_056_Microsoft.VisualStudio.Debugger.Concord.log                             10.05.2026 01:01:54   22481
dd_setup_20260510010142_055_Microsoft.VisualStudio.Debugger.Concord.Resources.log                   10.05.2026 01:01:54    2157
dd_setup_20260510010142_054_Microsoft.VisualStudio.Debugger.Resources.log                           10.05.2026 01:01:54    5323
dd_setup_20260510010142_053_Microsoft.DiaSymReader.PortablePdb.log                                  10.05.2026 01:01:54    1176
dd_setup_20260510010142_052_Microsoft.VisualStudio.PerfLib.log                                      10.05.2026 01:01:54    8469
dd_setup_20260510010142_051_Microsoft.VisualStudio.Debugger.Package.DiagHub.Client.log              10.05.2026 01:01:54    1110
dd_setup_20260510010142_050_Microsoft.VisualStudio.Debugger.Remote.DiagnosticsHub.Client.log        10.05.2026 01:01:53    1152
dd_setup_20260510010142_049_Microsoft.VisualStudio.Debugger.Remote.DiagnosticsHub.Client.log        10.05.2026 01:01:53    1152
dd_setup_20260510010142_048_Microsoft.VisualStudio.TextTemplating.MSBuild.log                       10.05.2026 01:01:53   13308
dd_setup_20260510010142_047_Microsoft.VisualStudio.TextTemplating.Integration.log                   10.05.2026 01:01:53   23722
dd_setup_20260510010142_046_Microsoft.VisualStudio.TextTemplating.Core.log                          10.05.2026 01:01:53   17887
dd_setup_20260510010142_045_Microsoft.CodeAnalysis.VisualStudio.Setup.log                           10.05.2026 01:01:53  711239
dd_setup_20260510010142_044_Microsoft.VisualStudio.TextTemplating.Integration.Resources.log         10.05.2026 01:01:52     586
dd_setup_20260510010142_043_Microsoft.VisualStudio.TestTools.DynamicCodeCoverage.log                10.05.2026 01:01:52   46134
dd_setup_20260510010142_042_Microsoft.VisualStudio.InstrumentationEngine.log                        10.05.2026 01:01:51    2451
dd_setup_20260510010142_041_Microsoft.CodeCoverage.Console.Targeted.log                             10.05.2026 01:01:51   74943
dd_setup_20260510010142_040_Microsoft.VisualStudio.TestTools.TestPlatform.V1.CLI.log                10.05.2026 01:01:51    6918
dd_setup_20260510010142_039_Microsoft.VisualStudio.TestTools.TestPlatform.V2.CLI.log                10.05.2026 01:01:51  414069
dd_setup_20260510010142_038_Microsoft.VisualStudio.VC.UnitTest.Desktop.Build.Core.log               10.05.2026 01:01:51   13707
dd_setup_20260510010142_037_Microsoft.VisualStudio.TestTools.TestPlatform.V1.CPP.log                10.05.2026 01:01:51    1416
dd_setup_20260510010142_036_Microsoft.VisualCpp.Tools.Common.Utils.log                              10.05.2026 01:01:51    4581
dd_setup_20260510010142_035_Microsoft.VisualCpp.Tools.Common.Utils.Resources.log                    10.05.2026 01:01:51    1611
dd_setup_20260510010142_034_Microsoft.VisualCpp.Servicing.Redist.log                                10.05.2026 01:01:50    3681
dd_setup_20260510010142_033_Microsoft.VisualStudio.VC.vcvars.log                                    10.05.2026 01:01:50    1731
dd_setup_20260510010142_032_Microsoft.VS.VC.vcvars.x86.Shortcuts.log                                10.05.2026 01:01:50     309
dd_setup_20260510010142_031_Microsoft.VS.VC.vcvars.x64.Shortcuts.log                                10.05.2026 01:01:50     309
dd_setup_20260510010142_030_Microsoft.Windows.UniversalCRT.Redistributable.Msi.log                  10.05.2026 01:01:50  423954
dd_setup_20260510010142_029_Microsoft.VisualStudio.VC.MSBuild.v170.x86.v143.log                     10.05.2026 01:01:50    2163
dd_setup_20260510010142_028_Microsoft.VisualStudio.VC.MSBuild.v170.X86.log                          10.05.2026 01:01:50    3591
dd_setup_20260510010142_027_Microsoft.VisualStudio.VC.MSBuild.v170.X64.v143.log                     10.05.2026 01:01:50    2139
dd_setup_20260510010142_026_Microsoft.VisualStudio.VC.MSBuild.v170.X64.log                          10.05.2026 01:01:50    3543
dd_setup_20260510010142_025_Microsoft.VisualStudio.VC.MSBuild.v170.ARM.v143.log                     10.05.2026 01:01:49    2139
dd_setup_20260510010142_024_Microsoft.VisualStudio.VC.MSBuild.v170.ARM.log                          10.05.2026 01:01:49    3543
dd_setup_20260510010142_023_Microsoft.VisualStudio.VC.MSBuild.v170.Base.log                         10.05.2026 01:01:49   82602
dd_setup_20260510010142_022_Microsoft.VisualStudio.VC.MSBuild.v170.Base.Resources.log               10.05.2026 01:01:49   38712
dd_setup_20260510010142_021_Microsoft.VisualStudio.Setup.WMIProvider.log                            10.05.2026 01:01:49  124332
dd_setup_20260510010142_020_Microsoft.VisualStudio.Setup.Configuration.Interop.log                  10.05.2026 01:01:48    1272
dd_setup_20260510010142_019_Microsoft.VisualStudio.Setup.Configuration.log                          10.05.2026 01:01:48  100052
dd_setup_20260510010142_018_Microsoft.VisualStudio.VsDevCmd.Ext.NetFxSdk.log                        10.05.2026 01:01:48    1002
dd_setup_20260510010142_017_Microsoft.VisualStudio.VsDevCmd.Core.WinSdk.log                         10.05.2026 01:01:47     996
dd_setup_20260510010142_016_Microsoft.VisualStudio.VsDevCmd.Core.DotNet.log                         10.05.2026 01:01:47     996
dd_setup_20260510010142_015_Microsoft.VisualStudio.VC.DevCmd.log                                    10.05.2026 01:01:47    9594
dd_setup_20260510010142_014_Microsoft.VisualStudio.VC.DevCmd.Resources.log                          10.05.2026 01:01:47    1140
dd_setup_20260510010142_013_Microsoft.VisualStudio.BuildTools.Resources.log                         10.05.2026 01:01:47    1044
dd_setup_20260510010142_012_Microsoft.VisualStudio.Net.Eula.Resources.log                           10.05.2026 01:01:47     990
dd_setup_20260510010142_011_Microsoft.Build.Dependencies.log                                        10.05.2026 01:01:47  435036
dd_setup_20260510010142_010_Microsoft.Build.FileTracker.Msi.log                                     10.05.2026 01:01:47  187394
dd_setup_20260510010142_009_Microsoft.PythonTools.BuildCore.Vsix.log                                10.05.2026 01:01:47   15561
dd_setup_20260510010142_008_Microsoft.NuGet.Build.Tasks.Setup.log                                   10.05.2026 01:01:46    6384
dd_setup_20260510010142_007_Microsoft.CodeAnalysis.Compilers.log                                    10.05.2026 01:01:46  106164
dd_setup_20260510010142_006_Microsoft.VisualStudio.NativeImageSupport.log                           10.05.2026 01:01:46    1497
dd_setup_20260510010142_005_Microsoft.Build.log                                                     10.05.2026 01:01:46  263505
dd_setup_20260510010142_004_Microsoft.VisualStudio.NuGet.BuildTools.log                             10.05.2026 01:01:45  224253
dd_setup_20260510010142_003_Microsoft.Build.UnGAC.log                                               10.05.2026 01:01:45    1491
dd_setup_20260510010142_002_Microsoft.VisualStudio.VC.Icons.log                                     10.05.2026 01:01:45     900
dd_setup_20260510010142_000_TestMSI.log                                                             10.05.2026 01:01:44   63154
dd_setup_20260510010142_errors.log                                                                  10.05.2026 01:01:42       0
dd_setup_20260510010139.log                                                                         10.05.2026 01:01:41   11007
dd_setup_20260510010139_errors.log                                                                  10.05.2026 01:01:39       0
dd_installer_20260510005907.log                                                                     10.05.2026 01:01:02   26304
dd_installer_elevated_20260510005913.log                                                            10.05.2026 01:00:57 3343488
dd_setup_20260510005916.log                                                                         10.05.2026 01:00:57 3334007
dd_setup_20260510005916_235_Microsoft.VisualStudio.VC.Icons.log                                     10.05.2026 01:00:57     476
dd_setup_20260510005916_234_Microsoft.VisualStudio.NuGet.BuildTools.log                             10.05.2026 01:00:57   67343
dd_setup_20260510005916_233_Microsoft.Build.log                                                     10.05.2026 01:00:57   67989
dd_setup_20260510005916_232_Microsoft.VisualStudio.NativeImageSupport.log                           10.05.2026 01:00:57     643
dd_setup_20260510005916_231_Microsoft.CodeAnalysis.Compilers.log                                    10.05.2026 01:00:57   29445
dd_setup_20260510005916_230_Microsoft.NuGet.Build.Tasks.Setup.log                                   10.05.2026 01:00:57    2112
dd_setup_20260510005916_229_Microsoft.PythonTools.BuildCore.Vsix.log                                10.05.2026 01:00:57    4851
dd_setup_20260510005916_228_Microsoft.Build.FileTracker.Msi.log                                     10.05.2026 01:00:57  148072
dd_setup_20260510005916_227_Microsoft.Build.Dependencies.log                                        10.05.2026 01:00:57  126692
dd_setup_20260510005916_226_Microsoft.VisualStudio.Net.Eula.Resources.log                           10.05.2026 01:00:56     506
dd_setup_20260510005916_225_Microsoft.VisualStudio.BuildTools.Resources.log                         10.05.2026 01:00:56     524
dd_setup_20260510005916_224_Microsoft.VisualStudio.VC.DevCmd.Resources.log                          10.05.2026 01:00:56     556
dd_setup_20260510005916_223_Microsoft.VisualStudio.VC.DevCmd.log                                    10.05.2026 01:00:56    2990
dd_setup_20260510005916_222_Microsoft.VisualStudio.VsDevCmd.Core.DotNet.log                         10.05.2026 01:00:56     508
dd_setup_20260510005916_221_Microsoft.VisualStudio.VsDevCmd.Core.WinSdk.log                         10.05.2026 01:00:56     508
dd_setup_20260510005916_220_Microsoft.VisualStudio.VsDevCmd.Ext.NetFxSdk.log                        10.05.2026 01:00:56     510
dd_setup_20260510005916_219_Microsoft.VisualStudio.Setup.Configuration.log                          10.05.2026 01:00:56   85044
dd_setup_20260510005916_218_Microsoft.VisualStudio.Setup.Configuration.Interop.log                  10.05.2026 01:00:56     600
dd_setup_20260510005916_217_Microsoft.VisualStudio.Setup.WMIProvider.log                            10.05.2026 01:00:56  103872
dd_setup_20260510005916_216_Microsoft.VisualStudio.VC.MSBuild.v170.Base.Resources.log               10.05.2026 01:00:55   11480
dd_setup_20260510005916_215_Microsoft.VisualStudio.VC.MSBuild.v170.Base.log                         10.05.2026 01:00:55   24510
dd_setup_20260510005916_214_Microsoft.VisualStudio.VC.MSBuild.v170.ARM.log                          10.05.2026 01:00:55    1261
dd_setup_20260510005916_213_Microsoft.VisualStudio.VC.MSBuild.v170.ARM.v143.log                     10.05.2026 01:00:55     857
dd_setup_20260510005916_212_Microsoft.VisualStudio.VC.MSBuild.v170.X64.log                          10.05.2026 01:00:55    1261
dd_setup_20260510005916_211_Microsoft.VisualStudio.VC.MSBuild.v170.X64.v143.log                     10.05.2026 01:00:55     857
dd_setup_20260510005916_210_Microsoft.VisualStudio.VC.MSBuild.v170.X86.log                          10.05.2026 01:00:55    1277
dd_setup_20260510005916_209_Microsoft.VisualStudio.VC.MSBuild.v170.x86.v143.log                     10.05.2026 01:00:55     865
dd_setup_20260510005916_208_Microsoft.Windows.UniversalCRT.Redistributable.Msi.log                  10.05.2026 01:00:55  350592
dd_setup_20260510005916_207_Microsoft.VS.VC.vcvars.x64.Shortcuts.log                                10.05.2026 01:00:54     295
dd_setup_20260510005916_206_Microsoft.VS.VC.vcvars.x86.Shortcuts.log                                10.05.2026 01:00:54     295
dd_setup_20260510005916_205_Microsoft.VisualStudio.VC.vcvars.log                                    10.05.2026 01:00:54     721
dd_setup_20260510005916_204_Microsoft.VisualCpp.Servicing.Redist.log                                10.05.2026 01:00:54    1307
dd_setup_20260510005916_203_Microsoft.VisualCpp.Tools.Common.Utils.Resources.log                    10.05.2026 01:00:54     681
dd_setup_20260510005916_202_Microsoft.VisualCpp.Tools.Common.Utils.log                              10.05.2026 01:00:54    1539
dd_setup_20260510005916_201_Microsoft.VisualStudio.TestTools.TestPlatform.V1.CPP.log                10.05.2026 01:00:54     648
dd_setup_20260510005916_200_Microsoft.VisualStudio.VC.UnitTest.Desktop.Build.Core.log               10.05.2026 01:00:54    4278
dd_setup_20260510005916_199_Microsoft.VisualStudio.TestTools.TestPlatform.V2.CLI.log                10.05.2026 01:00:54  121229
dd_setup_20260510005916_198_Microsoft.VisualStudio.TestTools.TestPlatform.V1.CLI.log                10.05.2026 01:00:54    2290
dd_setup_20260510005916_197_Microsoft.CodeCoverage.Console.Targeted.log                             10.05.2026 01:00:54   22821
dd_setup_20260510005916_196_Microsoft.VisualStudio.InstrumentationEngine.log                        10.05.2026 01:00:54     961
dd_setup_20260510005916_195_Microsoft.VisualStudio.TestTools.DynamicCodeCoverage.log                10.05.2026 01:00:54   13834
dd_setup_20260510005916_194_Microsoft.VisualStudio.TextTemplating.Integration.Resources.log         10.05.2026 01:00:54     594
dd_setup_20260510005916_193_Microsoft.CodeAnalysis.VisualStudio.Setup.log                           10.05.2026 01:00:53  201967
dd_setup_20260510005916_192_Microsoft.VisualStudio.TextTemplating.Core.log                          10.05.2026 01:00:53    5136
dd_setup_20260510005916_191_Microsoft.VisualStudio.TextTemplating.Integration.log                   10.05.2026 01:00:53    7229
dd_setup_20260510005916_190_Microsoft.VisualStudio.TextTemplating.MSBuild.log                       10.05.2026 01:00:53    3395
dd_setup_20260510005916_189_Microsoft.VisualStudio.Debugger.Remote.DiagnosticsHub.Client.log        10.05.2026 01:00:53     558
dd_setup_20260510005916_188_Microsoft.VisualStudio.Debugger.Remote.DiagnosticsHub.Client.log        10.05.2026 01:00:53     558
dd_setup_20260510005916_187_Microsoft.VisualStudio.Debugger.Package.DiagHub.Client.log              10.05.2026 01:00:53     546
dd_setup_20260510005916_186_Microsoft.VisualStudio.PerfLib.log                                      10.05.2026 01:00:53    2711
dd_setup_20260510005916_185_Microsoft.DiaSymReader.PortablePdb.log                                  10.05.2026 01:00:53     568
dd_setup_20260510005916_184_Microsoft.VisualStudio.Debugger.Resources.log                           10.05.2026 01:00:53    2380
dd_setup_20260510005916_183_Microsoft.VisualStudio.Debugger.Concord.Resources.log                   10.05.2026 01:00:53     863
dd_setup_20260510005916_182_Microsoft.VisualStudio.Debugger.Concord.log                             10.05.2026 01:00:53    6665
dd_setup_20260510005916_181_Microsoft.VisualStudio.MinShell.Auto.Resources.log                      10.05.2026 01:00:53    1656
dd_setup_20260510005916_180_Microsoft.VisualStudio.MinShell.Auto.log                                10.05.2026 01:00:53   10339
dd_setup_20260510005916_179_Microsoft.VisualStudio.CoreDotNet.log                                   10.05.2026 01:00:53   14269
dd_setup_20260510005916_178_Microsoft.VisualStudio.UIInternal.Resources.log                         10.05.2026 01:00:53     570
dd_setup_20260510005916_177_Microsoft.VisualStudio.UIInternal.log                                   10.05.2026 01:00:53   35172
dd_setup_20260510005916_176_Microsoft.VisualStudio.UIInternal.Guide.log                             10.05.2026 01:00:53   58978
dd_setup_20260510005916_175_Microsoft.VisualStudio.MinShell.Resources.log                           10.05.2026 01:00:53    3637
dd_setup_20260510005916_174_Microsoft.VisualStudio.Devenv.Config.log                                10.05.2026 01:00:53     482
dd_setup_20260510005916_173_Microsoft.VisualStudio.MinShell.Targeted.log                            10.05.2026 01:00:53   31016
dd_setup_20260510005916_172_Microsoft.VisualStudio.Platform.Editor.log                              10.05.2026 01:00:53   23979
dd_setup_20260510005916_171_Microsoft.VisualStudio.ExtensionManager.Auto.log                        10.05.2026 01:00:53    1487
dd_setup_20260510005916_170_Microsoft.VisualStudio.ExtensionManager.log                             10.05.2026 01:00:53   12062
dd_setup_20260510005916_169_Microsoft.VisualStudio.MefHosting.log                                   10.05.2026 01:00:53    1880
dd_setup_20260510005916_168_Microsoft.VisualStudio.LanguageServer.log                               10.05.2026 01:00:53   11071
dd_setup_20260510005916_167_Microsoft.VisualStudio.Extensibility.Container.log                      10.05.2026 01:00:53   14153
dd_setup_20260510005916_166_Microsoft.VisualStudio.VsWebProtocolSelector.Msi.log                    10.05.2026 01:00:52   79192
dd_setup_20260510005916_165_Microsoft.VisualStudio.GitHubProtocolHandler.Msi.log                    10.05.2026 01:00:52   80772
dd_setup_20260510005916_164_Microsoft.VisualStudio.IdentityDependencies.log                         10.05.2026 01:00:52    3269
dd_setup_20260510005916_163_Microsoft.VisualStudio.Licensing.log                                    10.05.2026 01:00:52     826
dd_setup_20260510005916_162_Microsoft.VisualStudio.Copilot.Contracts.log                            10.05.2026 01:00:52    3077
dd_setup_20260510005916_161_Microsoft.VisualStudio.OpenTelemetry.ClientExtensions.netfx.log         10.05.2026 01:00:52    1639
dd_setup_20260510005916_160_Microsoft.VisualStudio.OpenTelemetry.Collector.netfx.log                10.05.2026 01:00:52     658
dd_setup_20260510005916_159_Microsoft.VisualStudio.MinShell.log                                     10.05.2026 01:00:52   23482
dd_setup_20260510005916_158_Microsoft.IntelliTrace.DiagnosticsHub.log                               10.05.2026 01:00:52    4580
dd_setup_20260510005916_157_Microsoft.VisualStudio.VC.MSVCDis.log                                   10.05.2026 01:00:52     484
dd_setup_20260510005916_156_Microsoft.VisualStudio.Editors.log                                      10.05.2026 01:00:52    8961
dd_setup_20260510005916_155_Microsoft.VisualStudio.AzureSDK.log                                     10.05.2026 01:00:52    2692
dd_setup_20260510005916_154_Microsoft.VisualStudio.Debugger.log                                     10.05.2026 01:00:52   22845
dd_setup_20260510005916_153_Microsoft.VisualStudio.Debugger.Remote.Resources.log                    10.05.2026 01:00:52    1237
dd_setup_20260510005916_152_Microsoft.VisualStudio.Debugger.Remote.Resources.log                    10.05.2026 01:00:52     996
dd_setup_20260510005916_151_Microsoft.VisualStudio.Debugger.Concord.Remote.Resources.log            10.05.2026 01:00:52     564
dd_setup_20260510005916_150_Microsoft.VisualStudio.Debugger.Concord.Remote.log                      10.05.2026 01:00:52    4076
dd_setup_20260510005916_149_Microsoft.VisualStudio.Debugger.Remote.log                              10.05.2026 01:00:52   22970
dd_setup_20260510005916_148_Microsoft.VisualStudio.Debugger.Concord.Remote.Resources.log            10.05.2026 01:00:52     564
dd_setup_20260510005916_147_Microsoft.VisualStudio.Debugger.Concord.Remote.log                      10.05.2026 01:00:52    4076
dd_setup_20260510005916_146_Microsoft.VisualStudio.Debugger.Remote.log                              10.05.2026 01:00:52   22723
dd_setup_20260510005916_145_Microsoft.VisualStudio.Debugger.TargetComposition.Remote.log            10.05.2026 01:00:52     966
dd_setup_20260510005916_144_Microsoft.VisualStudio.Debugger.TargetComposition.Remote.log            10.05.2026 01:00:52     966
dd_setup_20260510005916_143_Microsoft.VisualStudio.Debugger.TargetComposition.log                   10.05.2026 01:00:52     846
dd_setup_20260510005916_142_Microsoft.VisualStudio.Debugger.Managed.Resources.log                   10.05.2026 01:00:52     815
dd_setup_20260510005916_141_Microsoft.VisualStudio.Debugger.Concord.Managed.Resources.log           10.05.2026 01:00:52     316
dd_setup_20260510005916_140_Microsoft.VisualStudio.Debugger.Concord.Managed.log                     10.05.2026 01:00:52    2989
dd_setup_20260510005916_139_Microsoft.CodeAnalysis.ExpressionEvaluator.log                          10.05.2026 01:00:52   14533
dd_setup_20260510005916_138_Microsoft.DiaSymReader.log                                              10.05.2026 01:00:52     544
dd_setup_20260510005916_137_Microsoft.VisualStudio.Debugger.Managed.log                             10.05.2026 01:00:52   13389
dd_setup_20260510005916_136_Microsoft.VisualStudio.Debugger.Parallel.Resources.log                  10.05.2026 01:00:52     570
dd_setup_20260510005916_135_Microsoft.VisualStudio.Debugger.Parallel.log                            10.05.2026 01:00:52    2152
dd_setup_20260510005916_134_Microsoft.VisualStudio.Debugger.CollectionAgents.log                    10.05.2026 01:00:51     831
dd_setup_20260510005916_133_Microsoft.VisualStudio.VC.Ide.Common.Resources.log                      10.05.2026 01:00:51     703
dd_setup_20260510005916_132_Microsoft.VisualStudio.VC.Ide.Common.log                                10.05.2026 01:00:51    3603
dd_setup_20260510005916_131_Microsoft.VisualStudio.VC.Ide.Debugger.Resources.log                    10.05.2026 01:00:51     763
dd_setup_20260510005916_130_Microsoft.VisualStudio.VC.Ide.Debugger.Concord.Resources.log            10.05.2026 01:00:51     715
dd_setup_20260510005916_129_Microsoft.VisualStudio.VC.Ide.Debugger.Concord.log                      10.05.2026 01:00:51    1249
dd_setup_20260510005916_128_Microsoft.VisualStudio.VC.Ide.Debugger.log                              10.05.2026 01:00:51    7144
dd_setup_20260510005916_127_Microsoft.WebTools.DotNet.Core.ItemTemplates.log                        10.05.2026 01:00:51    2434
dd_setup_20260510005916_126_Microsoft.WebTools.Shared.log                                           10.05.2026 01:00:51  125277
dd_setup_20260510005916_125_Microsoft.VisualStudio.Web.Azure.Common.log                             10.05.2026 01:00:51    3101
dd_setup_20260510005916_124_Microsoft.VisualStudio.Debugger.AzureAttach.log                         10.05.2026 01:00:51     935
dd_setup_20260510005916_123_Microsoft.VisualStudio.Debugger.VSCodeDebuggerHost.log                  10.05.2026 01:00:51    6619
dd_setup_20260510005916_122_Microsoft.VisualStudio.Debugger.BrokeredServices.log                    10.05.2026 01:00:51    5237
dd_setup_20260510005916_121_Microsoft.VisualStudio.VC.Ide.Base.Resources.log                        10.05.2026 01:00:51    1301
dd_setup_20260510005916_120_Microsoft.VisualStudio.VC.Llvm.Base.log                                 10.05.2026 01:00:51   23049
dd_setup_20260510005916_119_Microsoft.VisualStudio.VC.Ide.LanguageService.Resources.log             10.05.2026 01:00:51   13352
dd_setup_20260510005916_118_Microsoft.VisualStudio.VC.Ide.Core.VCProjectEngine.Resources.log        10.05.2026 01:00:51     451
dd_setup_20260510005916_117_Microsoft.VisualStudio.VC.Ide.Core.VCProjectEngine.log                  10.05.2026 01:00:51     574
dd_setup_20260510005916_116_Microsoft.VisualStudio.VC.Ide.ProjectSystem.Resources.log               10.05.2026 01:00:51    1498
dd_setup_20260510005916_115_Microsoft.VisualStudio.VC.Ide.ProjectSystem.log                         10.05.2026 01:00:51    5184
dd_setup_20260510005916_114_Microsoft.VisualStudio.VisualC.Utilities.Resources.log                  10.05.2026 01:00:51     309
dd_setup_20260510005916_113_Microsoft.VisualStudio.VisualC.Utilities.log                            10.05.2026 01:00:51     845
dd_setup_20260510005916_112_Microsoft.VisualStudio.VC.Ide.Core.log                                  10.05.2026 01:00:51    2061
dd_setup_20260510005916_111_Microsoft.VisualStudio.VC.Ide.LanguageService.Dependencies.log          10.05.2026 01:00:51     877
dd_setup_20260510005916_110_Microsoft.VisualStudio.VC.Ide.ResourceEditor.Resources.log              10.05.2026 01:00:51    1153
dd_setup_20260510005916_109_Microsoft.VisualStudio.VC.Ide.ResourceEditor.log                        10.05.2026 01:00:51    3692
dd_setup_20260510005916_108_Microsoft.VisualStudio.VC.Ide.VCPkgDatabase.log                         10.05.2026 01:00:51     564
dd_setup_20260510005916_107_Microsoft.VisualStudio.VC.Copilot.Setup.log                             10.05.2026 01:00:51    1489
dd_setup_20260510005916_106_Microsoft.VisualStudio.VC.Ide.LanguageService.log                       10.05.2026 01:00:51   15671
dd_setup_20260510005916_105_Microsoft.VisualStudio.VC.Ide.Base.log                                  10.05.2026 01:00:51   35766
dd_setup_20260510005916_104_Microsoft.VisualStudio.VC.Ide.Dskx.Resources.log                        10.05.2026 01:00:51     685
dd_setup_20260510005916_103_Microsoft.VisualStudio.VC.Ide.Dskx.log                                  10.05.2026 01:00:51    1622
dd_setup_20260510005916_102_Microsoft.VisualStudio.VC.Ide.WinXPlus.log                              10.05.2026 01:00:51    6123
dd_setup_20260510005916_101_Microsoft.VisualStudio.Debugger.Script.Remote.Resources.log             10.05.2026 01:00:51     568
dd_setup_20260510005916_100_Microsoft.VisualStudio.Debugger.Script.Remote.Resources.log             10.05.2026 01:00:51     568
dd_setup_20260510005916_099_Microsoft.VisualStudio.Debugger.Script.Remote.log                       10.05.2026 01:00:51     779
dd_setup_20260510005916_098_Microsoft.VisualStudio.Debugger.Script.Remote.log                       10.05.2026 01:00:51     783
dd_setup_20260510005916_097_Microsoft.VisualStudio.Debugger.Script.Resources.log                    10.05.2026 01:00:51     556
dd_setup_20260510005916_096_Microsoft.VisualStudio.Debugger.Script.log                              10.05.2026 01:00:51    1046
dd_setup_20260510005916_095_Microsoft.VisualStudio.Debugger.Script.Msi.log                          10.05.2026 01:00:51  171432
dd_setup_20260510005916_094_Microsoft.VisualStudio.VC.Ide.x64.log                                   10.05.2026 01:00:50     516
dd_setup_20260510005916_093_Microsoft.VisualStudio.Connected.Resources.log                          10.05.2026 01:00:50     301
dd_setup_20260510005916_092_Microsoft.VisualStudio.Connected.Auto.Resources.log                     10.05.2026 01:00:50     602
dd_setup_20260510005916_091_Microsoft.VisualStudio.Connected.Auto.log                               10.05.2026 01:00:50    1244
dd_setup_20260510005916_090_SQLitePCLRaw.Targeted.log                                               10.05.2026 01:00:50     578
dd_setup_20260510005916_089_SQLitePCLRaw.log                                                        10.05.2026 01:00:50    1289
dd_setup_20260510005916_088_Microsoft.Developer.IdentityServiceGS.log                               10.05.2026 01:00:50    4957
dd_setup_20260510005916_087_Microsoft.VisualStudio.Identity.log                                     10.05.2026 01:00:50  146891
dd_setup_20260510005916_086_Microsoft.VisualStudio.Connected.log                                    10.05.2026 01:00:50    7457
dd_setup_20260510005916_085_Microsoft.VisualStudio.Platform.NavigateTo.log                          10.05.2026 01:00:50    1711
dd_setup_20260510005916_084_Microsoft.VisualStudio.CoreEditor.UserProfiles.log                      10.05.2026 01:00:50    1680
dd_setup_20260510005916_083_Microsoft.VisualStudio.CoreEditor.log                                   10.05.2026 01:00:50    7589
dd_setup_20260510005916_082_Microsoft.VisualStudio.ErrorList.log                                    10.05.2026 01:00:50    5026
dd_setup_20260510005916_081_Microsoft.VisualStudio.Finalizer.log                                    10.05.2026 01:00:50    3511
dd_setup_20260510005916_080_Microsoft.VisualStudio.Log.Resources.log                                10.05.2026 01:00:50     488
dd_setup_20260510005916_079_Microsoft.VisualStudio.Log.Targeted.log                                 10.05.2026 01:00:50     556
dd_setup_20260510005916_078_Microsoft.VisualStudio.Log.log                                          10.05.2026 01:00:50    3476
dd_setup_20260510005916_077_Microsoft.VisualStudio.NgenRunner.log                                   10.05.2026 01:00:50     679
dd_setup_20260510005916_076_Microsoft.VisualStudio.MinShell.Interop.log                             10.05.2026 01:00:50   12219
dd_setup_20260510005916_075_Microsoft.VisualStudio.MinShell.Msi.Resources.log                       10.05.2026 01:00:50   75280
dd_setup_20260510005916_074_Microsoft.VisualStudio.MinShell.Shared.Msi.log                          10.05.2026 01:00:50   88222
dd_setup_20260510005916_073_Microsoft.VisualStudio.MinShell.Msi.log                                 10.05.2026 01:00:50   70024
dd_setup_20260510005916_072_Microsoft.VisualStudio.FileHandler.Msi.log                              10.05.2026 01:00:49  181406
dd_setup_20260510005916_071_Microsoft.VisualStudio.FileHandler.Msi.log                              10.05.2026 01:00:49  121252
dd_setup_20260510005916_070_Microsoft.VisualStudio.OpenFolder.VSIX.log                              10.05.2026 01:00:49   27743
dd_setup_20260510005916_069_Microsoft.ServiceHub.Managed.log                                        10.05.2026 01:00:49   14351
dd_setup_20260510005916_068_Microsoft.ServiceHub.Node.log                                           10.05.2026 01:00:48    1717
dd_setup_20260510005916_067_Microsoft.VisualStudio.Platform.Markdown.log                            10.05.2026 01:00:48   10307
dd_setup_20260510005916_066_Microsoft.VisualStudio.TextMateGrammars.log                             10.05.2026 01:00:48   97576
dd_setup_20260510005916_065_Microsoft.VisualStudio.GraphProvider.Auto.log                           10.05.2026 01:00:48    2096
dd_setup_20260510005916_064_Microsoft.VisualStudio.GraphProvider.log                                10.05.2026 01:00:48    3434
dd_setup_20260510005916_063_Microsoft.VisualStudio.GraphModel.log                                   10.05.2026 01:00:48     817
dd_setup_20260510005916_062_Microsoft.VisualStudio.PerformanceProvider.log                          10.05.2026 01:00:48     608
dd_setup_20260510005916_061_Microsoft.VisualStudio.VirtualTree.log                                  10.05.2026 01:00:48     576
dd_setup_20260510005916_060_Microsoft.VisualStudio.ScriptedHost.Targeted.log                        10.05.2026 01:00:48     528
dd_setup_20260510005916_059_Microsoft.VisualStudio.ScriptedHost.log                                 10.05.2026 01:00:48    1492
dd_setup_20260510005916_058_Microsoft.DiagnosticsHub.Collection.Service.log                         10.05.2026 01:00:48  107380
dd_setup_20260510005916_057_Microsoft.DiagnosticsHub.Collection.log                                 10.05.2026 01:00:48    4541
dd_setup_20260510005916_056_Microsoft.DiagnosticsHub.Runtime.log                                    10.05.2026 01:00:48   31030
dd_setup_20260510005916_055_Microsoft.VisualStudio.MinShell.Interop.Shared.Msi.log                  10.05.2026 01:00:48  447720
dd_setup_20260510005916_054_Microsoft.VisualStudio.MinShell.Interop.Msi.log                         10.05.2026 01:00:47 1807436
dd_setup_20260510005916_053_Microsoft.VisualStudio.Community.Shared.Msi.log                         10.05.2026 01:00:44  443880
dd_setup_20260510005916_052_Microsoft.VisualStudio.Community.Msi.log                                10.05.2026 01:00:43  250824
dd_setup_20260510005916_051_Microsoft.VisualStudio.Community.Msi.Resources.log                      10.05.2026 01:00:42   73330
dd_setup_20260510005916_050_Microsoft.VisualStudio.Community.ProductArch.Neutral.log                10.05.2026 01:00:41   37522
dd_setup_20260510005916_049_Microsoft.VisualStudio.Platform.CallHierarchy.log                       10.05.2026 01:00:41    5898
dd_setup_20260510005916_048_Microsoft.MSHtml.log                                                    10.05.2026 01:00:41     530
dd_setup_20260510005916_047_Microsoft.VisualStudio.Diagnostics.AspNetHelper.log                     10.05.2026 01:00:41     306
dd_setup_20260510005916_046_Microsoft.VisualStudio.WebSiteProject.DTE.log                           10.05.2026 01:00:41     984
dd_setup_20260510005916_045_Microsoft.VisualStudio.Community.ProductArch.Resources.Neutral.log      10.05.2026 01:00:41   13825
dd_setup_20260510005916_044_Microsoft.VisualStudio.Community.ProductArch.Resources.NeutralExtra.log 10.05.2026 01:00:41   32753
dd_setup_20260510005916_043_Microsoft.VisualStudio.Community.ProductArch.Resources.Targeted.log     10.05.2026 01:00:41    2867
dd_setup_20260510005916_042_Microsoft.VisualStudio.Community.CSharp.Resources.Neutral.log           10.05.2026 01:00:41   16425
dd_setup_20260510005916_041_Microsoft.VisualStudio.Community.CSharp.Resources.Targeted.log          10.05.2026 01:00:40     498
dd_setup_20260510005916_040_Microsoft.VisualStudio.Community.VB.Resources.Neutral.log               10.05.2026 01:00:40   93100
dd_setup_20260510005916_039_Microsoft.VisualStudio.Community.VB.Resources.Targeted.log              10.05.2026 01:00:40     842
dd_setup_20260510005916_038_Microsoft.IntelliTrace.CollectorCab.log                                 10.05.2026 01:00:40     867
dd_setup_20260510005916_037_Microsoft.VisualStudio.Community.ProductArch.NeutralExtra.log           10.05.2026 01:00:40    4292
dd_setup_20260510005916_036_Microsoft.VisualStudio.Community.ProductArch.Targeted.log               10.05.2026 01:00:40    8364
dd_setup_20260510005916_035_Microsoft.VisualStudio.Community.ProductArch.TargetedExtra.log          10.05.2026 01:00:40    1422
dd_setup_20260510005916_034_Microsoft.VisualStudio.Community.CSharp.Neutral.log                     10.05.2026 01:00:40    6356
dd_setup_20260510005916_033_Microsoft.VisualStudio.Community.CSharp.Targeted.log                    10.05.2026 01:00:40    1400
dd_setup_20260510005916_032_Microsoft.VisualStudio.Community.VB.Neutral.log                         10.05.2026 01:00:40    3274
dd_setup_20260510005916_031_Microsoft.VisualStudio.Community.VB.Targeted.log                        10.05.2026 01:00:40     969
dd_setup_20260510005916_030_Microsoft.VisualStudio.Community.x64.log                                10.05.2026 01:00:40    1233
dd_setup_20260510005916_029_Microsoft.VisualStudio.Community.x86.log                                10.05.2026 01:00:40    1267
dd_setup_20260510005916_028_Microsoft.VisualStudio.ProjectSystem.log                                10.05.2026 01:00:40   14694
dd_setup_20260510005916_027_Microsoft.VisualStudio.ProjectSystem.Query.log                          10.05.2026 01:00:40    9331
dd_setup_20260510005916_026_Microsoft.VisualStudio.LiveShareApi.log                                 10.05.2026 01:00:40     596
dd_setup_20260510005916_025_Microsoft.VisualStudio.ProjectSystem.Full.log                           10.05.2026 01:00:40     584
dd_setup_20260510005916_024_Microsoft.VisualStudio.ClientDiagnostics.Resources.log                  10.05.2026 01:00:40     660
dd_setup_20260510005916_023_Microsoft.VisualStudio.ClientDiagnostics.Targeted.log                   10.05.2026 01:00:40     853
dd_setup_20260510005916_022_Microsoft.VisualStudio.ClientDiagnostics.log                            10.05.2026 01:00:40    3758
dd_setup_20260510005916_021_Microsoft.VisualStudio.AppResponsiveness.Resources.log                  10.05.2026 01:00:40    1374
dd_setup_20260510005916_020_Microsoft.VisualStudio.AppResponsiveness.Targeted.log                   10.05.2026 01:00:40     640
dd_setup_20260510005916_019_Microsoft.VisualStudio.AppResponsiveness.log                            10.05.2026 01:00:40   15801
dd_setup_20260510005916_018_Microsoft.VisualStudio.TestTools.TeamFoundationClient.log               10.05.2026 01:00:39   10518
dd_setup_20260510005916_017_Microsoft.VisualStudio.CodeSense.Community.log                          10.05.2026 01:00:39    2055
dd_setup_20260510005916_016_Microsoft.VisualStudio.VC.Ide.MDD.log                                   10.05.2026 01:00:39    6744
dd_setup_20260510005916_015_Microsoft.VisualStudio.VC.Items.Pro.log                                 10.05.2026 01:00:39    1414
dd_setup_20260510005916_014_Microsoft.VisualStudio.VC.Templates.General.Resources.log               10.05.2026 01:00:39    4292
dd_setup_20260510005916_013_Microsoft.VisualStudio.VC.Templates.General.log                         10.05.2026 01:00:39   13505
dd_setup_20260510005916_012_Microsoft.VisualStudio.VC.Ide.Pro.Resources.log                         10.05.2026 01:00:39    4924
dd_setup_20260510005916_011_Microsoft.VisualStudio.VC.Ide.Pro.log                                   10.05.2026 01:00:39     292
dd_setup_20260510005916_010_Microsoft.VisualStudio.VC.Templates.Desktop.log                         10.05.2026 01:00:39    5808
dd_setup_20260510005916_009_Microsoft.VisualStudio.VC.Templates.UnitTest.Resources.log              10.05.2026 01:00:39    1704
dd_setup_20260510005916_008_Microsoft.VisualStudio.VC.Templates.UnitTest.log                        10.05.2026 01:00:39    2672
dd_setup_20260510005916_007_Microsoft.VisualStudio.TestTools.TestPlatform.IDE.log                   10.05.2026 01:00:39  316465
dd_setup_20260510005916_006_Microsoft.VisualStudio.TestTools.TestWIExtension.log                    10.05.2026 01:00:38    1428
dd_setup_20260510005916_005_Microsoft.VisualStudio.VC.Ide.Linux.ConnectionManager.Resources.log     10.05.2026 01:00:38    3613
dd_setup_20260510005916_004_Microsoft.VisualStudio.VC.Ide.Linux.Shared.Resources.log                10.05.2026 01:00:38     596
dd_setup_20260510005916_003_Microsoft.VisualStudio.VC.Ide.Linux.Shared.log                          10.05.2026 01:00:38     570
dd_setup_20260510005916_002_Microsoft.VisualStudio.VC.Ide.Linux.ConnectionManager.log               10.05.2026 01:00:38    5555
dd_setup_20260510005916_001_Win11SDK_10.0.22621.log                                                 10.05.2026 01:00:38     730
dd_setup_20260510005916_errors.log                                                                  10.05.2026 00:59:16       0
dd_setup_20260510005913.log                                                                         10.05.2026 00:59:14    7882
dd_setup_20260510005913_errors.log                                                                  10.05.2026 00:59:13       0
dd_bootstrapper_20260510004912.log                                                                  10.05.2026 00:51:36    7185
dd_installer_20260510004923.log                                                                     10.05.2026 00:51:36   31798
dd_installer_elevated_20260510004929.log                                                            10.05.2026 00:51:36 5144674
dd_setup_20260510005135.log                                                                         10.05.2026 00:51:36    8252
dd_setup_20260510005135_errors.log                                                                  10.05.2026 00:51:35       0
dd_setup_20260510004930.log                                                                         10.05.2026 00:51:35 4510795
dd_setup_20260510004930_239_Win11SDK_10.0.22621.log                                                 10.05.2026 00:51:33     719
dd_setup_20260510004930_238_Microsoft.VisualStudio.VC.Ide.Linux.ConnectionManager.log               10.05.2026 00:50:17   14871
dd_setup_20260510004930_237_Microsoft.VisualStudio.VC.Ide.Linux.Shared.log                          10.05.2026 00:50:17    1026
dd_setup_20260510004930_236_Microsoft.VisualStudio.VC.Ide.Linux.Shared.Resources.log                10.05.2026 00:50:17    1104
dd_setup_20260510004930_235_Microsoft.VisualStudio.VC.Ide.Linux.ConnectionManager.Resources.log     10.05.2026 00:50:17    9531
dd_setup_20260510004930_234_Microsoft.VisualStudio.TestTools.TestWIExtension.log                    10.05.2026 00:50:17    3516
dd_setup_20260510004930_233_Microsoft.VisualStudio.TestTools.TestPlatform.IDE.log                   10.05.2026 00:50:17  886682
dd_setup_20260510004930_232_Microsoft.VisualStudio.VC.Templates.UnitTest.log                        10.05.2026 00:50:16    6852
dd_setup_20260510004930_231_Microsoft.VisualStudio.VC.Templates.UnitTest.Resources.log              10.05.2026 00:50:16    4188
dd_setup_20260510004930_230_Microsoft.VisualStudio.VC.Templates.Desktop.log                         10.05.2026 00:50:16   15540
dd_setup_20260510004930_229_Microsoft.VisualStudio.VC.Ide.Pro.log                                   10.05.2026 00:50:15     309
dd_setup_20260510004930_228_Microsoft.VisualStudio.VC.Ide.Pro.Resources.log                         10.05.2026 00:50:15   13128
dd_setup_20260510004930_227_Microsoft.VisualStudio.VC.Templates.General.log                         10.05.2026 00:50:15   36411
dd_setup_20260510004930_226_Microsoft.VisualStudio.VC.Templates.General.Resources.log               10.05.2026 00:50:14   11352
dd_setup_20260510004930_225_Microsoft.VisualStudio.VC.Items.Pro.log                                 10.05.2026 00:50:14    3318
dd_setup_20260510004930_224_Microsoft.VisualStudio.VC.Ide.MDD.log                                   10.05.2026 00:50:14   18228
dd_setup_20260510004930_223_Microsoft.VisualStudio.CodeSense.Community.log                          10.05.2026 00:50:14    6190
dd_setup_20260510004930_222_Microsoft.VisualStudio.TestTools.TeamFoundationClient.log               10.05.2026 00:50:14   33340
dd_setup_20260510004930_221_Microsoft.VisualStudio.AppResponsiveness.log                            10.05.2026 00:50:14   44019
dd_setup_20260510004930_220_Microsoft.VisualStudio.AppResponsiveness.Targeted.log                   10.05.2026 00:50:14    1236
dd_setup_20260510004930_219_Microsoft.VisualStudio.AppResponsiveness.Resources.log                  10.05.2026 00:50:14    3318
dd_setup_20260510004930_218_Microsoft.VisualStudio.ClientDiagnostics.log                            10.05.2026 00:50:14    9870
dd_setup_20260510004930_217_Microsoft.VisualStudio.ClientDiagnostics.Targeted.log                   10.05.2026 00:50:14    1827
dd_setup_20260510004930_216_Microsoft.VisualStudio.ClientDiagnostics.Resources.log                  10.05.2026 00:50:14    1296
dd_setup_20260510004930_215_Microsoft.VisualStudio.ProjectSystem.Full.log                           10.05.2026 00:50:14     594
dd_setup_20260510004930_214_Microsoft.VisualStudio.LiveShareApi.log                                 10.05.2026 00:50:14    1104
dd_setup_20260510004930_213_Microsoft.VisualStudio.ProjectSystem.Query.log                          10.05.2026 00:50:14   26035
dd_setup_20260510004930_212_Microsoft.VisualStudio.ProjectSystem.log                                10.05.2026 00:50:14   41418
dd_setup_20260510004930_211_Microsoft.VisualStudio.Community.x86.log                                10.05.2026 00:50:13    2943
dd_setup_20260510004930_210_Microsoft.VisualStudio.Community.x64.log                                10.05.2026 00:50:13    2769
dd_setup_20260510004930_209_Microsoft.VisualStudio.Community.VB.Targeted.log                        10.05.2026 00:50:13    2043
dd_setup_20260510004930_208_Microsoft.VisualStudio.Community.VB.Neutral.log                         10.05.2026 00:50:13    8658
dd_setup_20260510004930_207_Microsoft.VisualStudio.Community.CSharp.Targeted.log                    10.05.2026 00:50:13    3515
dd_setup_20260510004930_206_Microsoft.VisualStudio.Community.CSharp.Neutral.log                     10.05.2026 00:50:13   16908
dd_setup_20260510004930_205_Microsoft.VisualStudio.Community.ProductArch.TargetedExtra.log          10.05.2026 00:50:13    3342
dd_setup_20260510004930_204_Microsoft.VisualStudio.Community.ProductArch.Targeted.log               10.05.2026 00:50:13   22519
dd_setup_20260510004930_203_Microsoft.VisualStudio.Community.ProductArch.NeutralExtra.log           10.05.2026 00:50:13   11472
dd_setup_20260510004930_202_Microsoft.IntelliTrace.CollectorCab.log                                 10.05.2026 00:50:13    1857
dd_setup_20260510004930_201_Microsoft.VisualStudio.Community.VB.Resources.Targeted.log              10.05.2026 00:50:13    1722
dd_setup_20260510004930_200_Microsoft.VisualStudio.Community.VB.Resources.Neutral.log               10.05.2026 00:50:13  260004
dd_setup_20260510004930_199_Microsoft.VisualStudio.Community.CSharp.Resources.Targeted.log          10.05.2026 00:50:13     816
dd_setup_20260510004930_198_Microsoft.VisualStudio.Community.CSharp.Resources.Neutral.log           10.05.2026 00:50:12   45219
dd_setup_20260510004930_197_Microsoft.VisualStudio.Community.ProductArch.Resources.Targeted.log     10.05.2026 00:50:12    7275
dd_setup_20260510004930_196_Microsoft.VisualStudio.Community.ProductArch.Resources.NeutralExtra.log 10.05.2026 00:50:12   33631
dd_setup_20260510004930_195_Microsoft.VisualStudio.Community.ProductArch.Resources.Neutral.log      10.05.2026 00:50:12   37251
dd_setup_20260510004930_194_Microsoft.VisualStudio.WebSiteProject.DTE.log                           10.05.2026 00:50:12    2148
dd_setup_20260510004930_193_Microsoft.VisualStudio.Diagnostics.AspNetHelper.log                     10.05.2026 00:50:12     309
dd_setup_20260510004930_192_Microsoft.MSHtml.log                                                    10.05.2026 00:50:12     906
dd_setup_20260510004930_191_Microsoft.VisualStudio.Platform.CallHierarchy.log                       10.05.2026 00:50:12   15930
dd_setup_20260510004930_190_Microsoft.VisualStudio.Community.ProductArch.Neutral.log                10.05.2026 00:50:12  107783
dd_setup_20260510004930_189_Microsoft.VisualStudio.Community.Msi.Resources.log                      10.05.2026 00:50:12   88296
dd_setup_20260510004930_188_Microsoft.VisualStudio.Community.Msi.log                                10.05.2026 00:50:11  292652
dd_setup_20260510004930_187_Microsoft.VisualStudio.Community.Shared.Msi.log                         10.05.2026 00:50:11  689708
dd_setup_20260510004930_186_Microsoft.VisualStudio.MinShell.Interop.Msi.log                         10.05.2026 00:50:09 1807824
dd_setup_20260510004930_185_Microsoft.VisualStudio.MinShell.Interop.Shared.Msi.log                  10.05.2026 00:50:06  456590
dd_setup_20260510004930_184_Microsoft.DiagnosticsHub.Runtime.log                                    10.05.2026 00:50:05   87596
dd_setup_20260510004930_183_Microsoft.DiagnosticsHub.Collection.log                                 10.05.2026 00:50:05   12135
dd_setup_20260510004930_182_Microsoft.DiagnosticsHub.Collection.Service.log                         10.05.2026 00:50:05  129034
dd_setup_20260510004930_181_Microsoft.VisualStudio.ScriptedHost.log                                 10.05.2026 00:50:04    3839
dd_setup_20260510004930_180_Microsoft.VisualStudio.ScriptedHost.Targeted.log                        10.05.2026 00:50:04     900
dd_setup_20260510004930_179_Microsoft.VisualStudio.VirtualTree.log                                  10.05.2026 00:50:04    1044
dd_setup_20260510004930_178_Microsoft.VisualStudio.PerformanceProvider.log                          10.05.2026 00:50:04    1465
dd_setup_20260510004930_177_Microsoft.VisualStudio.GraphModel.log                                   10.05.2026 00:50:04    1988
dd_setup_20260510004930_176_Microsoft.VisualStudio.GraphProvider.log                                10.05.2026 00:50:04   11847
dd_setup_20260510004930_175_Microsoft.VisualStudio.GraphProvider.Auto.log                           10.05.2026 00:50:04    6200
dd_setup_20260510004930_174_Microsoft.VisualStudio.TextMateGrammars.log                             10.05.2026 00:50:04  264345
dd_setup_20260510004930_173_Microsoft.VisualStudio.Platform.Markdown.log                            10.05.2026 00:50:04   27837
dd_setup_20260510004930_172_Microsoft.ServiceHub.Node.log                                           10.05.2026 00:50:04    4167
dd_setup_20260510004930_171_Microsoft.ServiceHub.Managed.log                                        10.05.2026 00:50:04   40938
dd_setup_20260510004930_170_Microsoft.VisualStudio.OpenFolder.VSIX.log                              10.05.2026 00:50:04   79147
dd_setup_20260510004930_169_Microsoft.VisualStudio.FileHandler.Msi.log                              10.05.2026 00:50:03  132248
dd_setup_20260510004930_168_Microsoft.VisualStudio.FileHandler.Msi.log                              10.05.2026 00:50:03  166470
dd_setup_20260510004930_167_Microsoft.VisualStudio.MinShell.Msi.log                                 10.05.2026 00:50:02   83120
dd_setup_20260510004930_166_Microsoft.VisualStudio.MinShell.Shared.Msi.log                          10.05.2026 00:50:02  104060
dd_setup_20260510004930_165_Microsoft.VisualStudio.MinShell.Msi.Resources.log                       10.05.2026 00:50:01   88456
dd_setup_20260510004930_164_Microsoft.VisualStudio.MinShell.Interop.log                             10.05.2026 00:50:01   33603
dd_setup_20260510004930_163_Microsoft.VisualStudio.NgenRunner.log                                   10.05.2026 00:50:01    1293
dd_setup_20260510004930_162_CoreEditorFonts.log                                                     10.05.2026 00:50:01   81780
dd_setup_20260510004930_161_Microsoft.VisualStudio.Log.log                                          10.05.2026 00:50:01    9354
dd_setup_20260510004930_160_Microsoft.VisualStudio.Log.Targeted.log                                 10.05.2026 00:50:00     990
dd_setup_20260510004930_159_Microsoft.VisualStudio.Log.Resources.log                                10.05.2026 00:50:00     780
dd_setup_20260510004930_158_Microsoft.VisualStudio.Finalizer.log                                    10.05.2026 00:50:00    9069
dd_setup_20260510004930_157_Microsoft.VisualStudio.ErrorList.log                                    10.05.2026 00:50:00   13581
dd_setup_20260510004930_156_Microsoft.VisualStudio.CoreEditor.log                                   10.05.2026 00:50:00   20091
dd_setup_20260510004930_155_Microsoft.VisualStudio.CoreEditor.UserProfiles.log                      10.05.2026 00:50:00    3996
dd_setup_20260510004930_154_Microsoft.VisualStudio.Platform.NavigateTo.log                          10.05.2026 00:50:00    4149
dd_setup_20260510004930_153_Microsoft.VisualStudio.Connected.log                                    10.05.2026 00:50:00   24186
dd_setup_20260510004930_152_Microsoft.VisualStudio.Identity.log                                     10.05.2026 00:50:00  409665
dd_setup_20260510004930_151_Microsoft.Developer.IdentityServiceGS.log                               10.05.2026 00:49:59   13047
dd_setup_20260510004930_150_SQLitePCLRaw.log                                                        10.05.2026 00:49:59    4093
dd_setup_20260510004930_149_SQLitePCLRaw.Targeted.log                                               10.05.2026 00:49:59    1050
dd_setup_20260510004930_148_Microsoft.VisualStudio.Connected.Auto.log                               10.05.2026 00:49:59    3221
dd_setup_20260510004930_147_Microsoft.VisualStudio.Connected.Auto.Resources.log                     10.05.2026 00:49:59    1122
dd_setup_20260510004930_146_Microsoft.VisualStudio.Connected.Resources.log                          10.05.2026 00:49:59     309
dd_setup_20260510004930_145_Microsoft.VisualStudio.VC.Ide.x64.log                                   10.05.2026 00:49:59     864
dd_setup_20260510004930_144_Microsoft.VisualStudio.Debugger.Script.Msi.log                          10.05.2026 00:49:59 1689554
dd_setup_20260510004930_143_Microsoft.VisualStudio.Debugger.Script.log                              10.05.2026 00:49:56    2334
dd_setup_20260510004930_142_Microsoft.VisualStudio.Debugger.Script.Resources.log                    10.05.2026 00:49:56     984
dd_setup_20260510004930_141_Microsoft.VisualStudio.Debugger.Script.Remote.log                       10.05.2026 00:49:56    1617
dd_setup_20260510004930_140_Microsoft.VisualStudio.Debugger.Script.Remote.log                       10.05.2026 00:49:56    1605
dd_setup_20260510004930_139_Microsoft.VisualStudio.Debugger.Script.Remote.Resources.log             10.05.2026 00:49:56    1026
dd_setup_20260510004930_138_Microsoft.VisualStudio.Debugger.Script.Remote.Resources.log             10.05.2026 00:49:56    1026
dd_setup_20260510004930_137_Microsoft.VisualStudio.VC.Ide.WinXPlus.log                              10.05.2026 00:49:56   16425
dd_setup_20260510004930_136_Microsoft.VisualStudio.VC.Ide.Dskx.log                                  10.05.2026 00:49:56    3822
dd_setup_20260510004930_135_Microsoft.VisualStudio.VC.Ide.Dskx.Resources.log                        10.05.2026 00:49:56    1311
dd_setup_20260510004930_134_Microsoft.VisualStudio.VC.Ide.Base.log                                  10.05.2026 00:49:56   98598
dd_setup_20260510004930_133_Microsoft.VisualStudio.VC.Ide.LanguageService.log                       10.05.2026 00:49:56   43221
dd_setup_20260510004930_132_Microsoft.VisualStudio.VC.Copilot.Setup.log                             10.05.2026 00:49:56    3603
dd_setup_20260510004930_131_Microsoft.VisualStudio.VC.Ide.VCPkgDatabase.log                         10.05.2026 00:49:56    1008
dd_setup_20260510004930_130_Microsoft.VisualStudio.VC.Ide.ResourceEditor.log                        10.05.2026 00:49:56    9552
dd_setup_20260510004930_129_Microsoft.VisualStudio.VC.Ide.ResourceEditor.Resources.log              10.05.2026 00:49:55    2595
dd_setup_20260510004930_128_Microsoft.VisualStudio.VC.Ide.LanguageService.Dependencies.log          10.05.2026 00:49:55    1887
dd_setup_20260510004930_127_Microsoft.VisualStudio.VC.Ide.Core.log                                  10.05.2026 00:49:55    5079
dd_setup_20260510004930_126_Microsoft.VisualStudio.VisualC.Utilities.log                            10.05.2026 00:49:55    1791
dd_setup_20260510004930_125_Microsoft.VisualStudio.VisualC.Utilities.Resources.log                  10.05.2026 00:49:55     309
dd_setup_20260510004930_124_Microsoft.VisualStudio.VC.Ide.ProjectSystem.log                         10.05.2026 00:49:55   14788
dd_setup_20260510004930_123_Microsoft.VisualStudio.VC.Ide.ProjectSystem.Resources.log               10.05.2026 00:49:55    3570
dd_setup_20260510004930_122_Microsoft.VisualStudio.VC.Ide.Core.VCProjectEngine.log                  10.05.2026 00:49:55    1038
dd_setup_20260510004930_121_Microsoft.VisualStudio.VC.Ide.Core.VCProjectEngine.Resources.log        10.05.2026 00:49:55    1056
dd_setup_20260510004930_120_Microsoft.VisualStudio.VC.Ide.LanguageService.Resources.log             10.05.2026 00:49:55   36456
dd_setup_20260510004930_119_Microsoft.VisualStudio.VC.Llvm.Base.log                                 10.05.2026 00:49:55   62403
dd_setup_20260510004930_118_Microsoft.VisualStudio.VC.Ide.Base.Resources.log                        10.05.2026 00:49:54    3039
dd_setup_20260510004930_117_Microsoft.VisualStudio.Debugger.BrokeredServices.log                    10.05.2026 00:49:54   14381
dd_setup_20260510004930_116_Microsoft.VisualStudio.Debugger.VSCodeDebuggerHost.log                  10.05.2026 00:49:54   17853
dd_setup_20260510004930_115_Microsoft.VisualStudio.Debugger.AzureAttach.log                         10.05.2026 00:49:54    2061
dd_setup_20260510004930_114_Microsoft.VisualStudio.Web.Azure.Common.log                             10.05.2026 00:49:54    8139
dd_setup_20260510004930_113_Microsoft.WebTools.Shared.log                                           10.05.2026 00:49:53  358163
dd_setup_20260510004930_112_Microsoft.WebTools.DotNet.Core.ItemTemplates.log                        10.05.2026 00:49:53    6300
dd_setup_20260510004930_111_Microsoft.VisualStudio.VC.Ide.Debugger.log                              10.05.2026 00:49:53   19068
dd_setup_20260510004930_110_Microsoft.VisualStudio.VC.Ide.Debugger.Concord.log                      10.05.2026 00:49:53    2883
dd_setup_20260510004930_109_Microsoft.VisualStudio.VC.Ide.Debugger.Concord.Resources.log            10.05.2026 00:49:53    1401
dd_setup_20260510004930_108_Microsoft.VisualStudio.VC.Ide.Debugger.Resources.log                    10.05.2026 00:49:53    1545
dd_setup_20260510004930_107_Microsoft.VisualStudio.VC.Ide.Common.log                                10.05.2026 00:49:53    9168
dd_setup_20260510004930_106_Microsoft.VisualStudio.VC.Ide.Common.Resources.log                      10.05.2026 00:49:53    1365
dd_setup_20260510004930_105_Microsoft.VisualStudio.Debugger.CollectionAgents.log                    10.05.2026 00:49:53    1761
dd_setup_20260510004930_104_Microsoft.VisualStudio.Debugger.Parallel.log                            10.05.2026 00:49:53    6012
dd_setup_20260510004930_103_Microsoft.VisualStudio.Debugger.Parallel.Resources.log                  10.05.2026 00:49:53    1026
dd_setup_20260510004930_102_Microsoft.VisualStudio.Debugger.Managed.log                             10.05.2026 00:49:53   36783
dd_setup_20260510004930_101_Microsoft.DiaSymReader.log                                              10.05.2026 00:49:53     948
dd_setup_20260510004930_100_Microsoft.CodeAnalysis.ExpressionEvaluator.log                          10.05.2026 00:49:53   44194
dd_setup_20260510004930_099_Microsoft.VisualStudio.Debugger.Concord.Managed.log                     10.05.2026 00:49:52    8588
dd_setup_20260510004930_098_Microsoft.VisualStudio.Debugger.Concord.Managed.Resources.log           10.05.2026 00:49:52     309
dd_setup_20260510004930_097_Microsoft.VisualStudio.Debugger.Managed.Resources.log                   10.05.2026 00:49:52    1701
dd_setup_20260510004930_096_Microsoft.VisualStudio.Debugger.TargetComposition.log                   10.05.2026 00:49:52    1734
dd_setup_20260510004930_095_Microsoft.VisualStudio.Debugger.TargetComposition.Remote.log            10.05.2026 00:49:52    2112
dd_setup_20260510004930_094_Microsoft.VisualStudio.Debugger.TargetComposition.Remote.log            10.05.2026 00:49:52    2112
dd_setup_20260510004930_093_Microsoft.VisualStudio.Debugger.Remote.log                              10.05.2026 00:49:52   62679
dd_setup_20260510004930_092_Microsoft.VisualStudio.Debugger.Concord.Remote.log                      10.05.2026 00:49:52   12205
dd_setup_20260510004930_091_Microsoft.VisualStudio.Debugger.Concord.Remote.Resources.log            10.05.2026 00:49:52    1014
dd_setup_20260510004930_090_Microsoft.VisualStudio.Debugger.Remote.log                              10.05.2026 00:49:52   63366
dd_setup_20260510004930_089_Microsoft.VisualStudio.Debugger.Concord.Remote.log                      10.05.2026 00:49:51   10794
dd_setup_20260510004930_088_Microsoft.VisualStudio.Debugger.Concord.Remote.Resources.log            10.05.2026 00:49:51    1014
dd_setup_20260510004930_087_Microsoft.VisualStudio.Debugger.Remote.Resources.log                    10.05.2026 00:49:51    2202
dd_setup_20260510004930_086_Microsoft.VisualStudio.Debugger.Remote.Resources.log                    10.05.2026 00:49:51    2871
dd_setup_20260510004930_085_Microsoft.VisualStudio.Debugger.log                                     10.05.2026 00:49:51   64458
dd_setup_20260510004930_084_Microsoft.VisualStudio.AzureSDK.log                                     10.05.2026 00:49:51    6912
dd_setup_20260510004930_083_Microsoft.VisualStudio.Editors.log                                      10.05.2026 00:49:51   24823
dd_setup_20260510004930_082_Microsoft.VisualStudio.VC.MSVCDis.log                                   10.05.2026 00:49:51     768
dd_setup_20260510004930_081_Microsoft.IntelliTrace.DiagnosticsHub.log                               10.05.2026 00:49:51   12649
dd_setup_20260510004930_080_Microsoft.VisualStudio.MinShell.log                                     10.05.2026 00:49:51   74259
dd_setup_20260510004930_079_Microsoft.VisualStudio.OpenTelemetry.Collector.netfx.log                10.05.2026 00:49:50    1290
dd_setup_20260510004930_078_Microsoft.VisualStudio.OpenTelemetry.ClientExtensions.netfx.log         10.05.2026 00:49:50    4053
dd_setup_20260510004930_077_Microsoft.VisualStudio.Copilot.Contracts.log                            10.05.2026 00:49:50    7947
dd_setup_20260510004930_076_Microsoft.VisualStudio.Licensing.log                                    10.05.2026 00:49:50    1674
dd_setup_20260510004930_075_Microsoft.VisualStudio.IdentityDependencies.log                         10.05.2026 00:49:50    8463
dd_setup_20260510004930_074_Microsoft.VisualStudio.GitHubProtocolHandler.Msi.log                    10.05.2026 00:49:50   98348
dd_setup_20260510004930_073_Microsoft.VisualStudio.VsWebProtocolSelector.Msi.log                    10.05.2026 00:49:50   93428
dd_setup_20260510004930_072_Microsoft.VisualStudio.Extensibility.Container.log                      10.05.2026 00:49:49   38835
dd_setup_20260510004930_071_Microsoft.VisualStudio.LanguageServer.log                               10.05.2026 00:49:49   31901
dd_setup_20260510004930_070_Microsoft.VisualStudio.MefHosting.log                                   10.05.2026 00:49:49    5761
dd_setup_20260510004930_069_Microsoft.VisualStudio.Initializer.log                                  10.05.2026 00:49:49    1274
dd_setup_20260510004930_068_Microsoft.VisualStudio.ExtensionManager.log                             10.05.2026 00:49:49   34212
dd_setup_20260510004930_067_Microsoft.VisualStudio.ExtensionManager.Auto.log                        10.05.2026 00:49:49    4080
dd_setup_20260510004930_066_Microsoft.VisualStudio.Platform.Editor.log                              10.05.2026 00:49:49   69797
dd_setup_20260510004930_065_Microsoft.VisualStudio.MinShell.Targeted.log                            10.05.2026 00:49:48   83995
dd_setup_20260510004930_064_Microsoft.VisualStudio.Devenv.Config.log                                10.05.2026 00:49:48     762
dd_setup_20260510004930_063_Microsoft.VisualStudio.MinShell.Resources.log                           10.05.2026 00:49:48    8761
dd_setup_20260510004930_062_Microsoft.VisualStudio.UIInternal.Guide.log                             10.05.2026 00:49:48  165090
dd_setup_20260510004930_061_Microsoft.VisualStudio.UIInternal.log                                   10.05.2026 00:49:47   98013
dd_setup_20260510004930_060_Microsoft.VisualStudio.UIInternal.Resources.log                         10.05.2026 00:49:47    1026
dd_setup_20260510004930_059_Microsoft.VisualStudio.CoreDotNet.log                                   10.05.2026 00:49:47   51146
dd_setup_20260510004930_058_Microsoft.VisualStudio.MinShell.Auto.log                                10.05.2026 00:49:47   29910
dd_setup_20260510004930_057_Microsoft.VisualStudio.MinShell.Auto.Resources.log                      10.05.2026 00:49:47    4044
dd_setup_20260510004930_056_Microsoft.VisualStudio.Debugger.Concord.log                             10.05.2026 00:49:47   18321
dd_setup_20260510004930_055_Microsoft.VisualStudio.Debugger.Concord.Resources.log                   10.05.2026 00:49:47    1845
dd_setup_20260510004930_054_Microsoft.VisualStudio.Debugger.Resources.log                           10.05.2026 00:49:47    4543
dd_setup_20260510004930_053_Microsoft.DiaSymReader.PortablePdb.log                                  10.05.2026 00:49:47    1020
dd_setup_20260510004930_052_Microsoft.VisualStudio.PerfLib.log                                      10.05.2026 00:49:47    6909
dd_setup_20260510004930_051_Microsoft.VisualStudio.Debugger.Package.DiagHub.Client.log              10.05.2026 00:49:47     954
dd_setup_20260510004930_050_Microsoft.VisualStudio.Debugger.Remote.DiagnosticsHub.Client.log        10.05.2026 00:49:47     996
dd_setup_20260510004930_049_Microsoft.VisualStudio.Debugger.Remote.DiagnosticsHub.Client.log        10.05.2026 00:49:47     996
dd_setup_20260510004930_048_Microsoft.VisualStudio.TextTemplating.MSBuild.log                       10.05.2026 00:49:47   11384
dd_setup_20260510004930_047_Microsoft.VisualStudio.TextTemplating.Integration.log                   10.05.2026 00:49:47   19926
dd_setup_20260510004930_046_Microsoft.VisualStudio.TextTemplating.Core.log                          10.05.2026 00:49:47   14455
dd_setup_20260510004930_045_Microsoft.CodeAnalysis.VisualStudio.Setup.log                           10.05.2026 00:49:46  597463
dd_setup_20260510004930_044_Microsoft.VisualStudio.TextTemplating.Integration.Resources.log         10.05.2026 00:49:41     586
dd_setup_20260510004930_043_Microsoft.VisualStudio.TestTools.DynamicCodeCoverage.log                10.05.2026 00:49:41   38490
dd_setup_20260510004930_042_Microsoft.VisualStudio.InstrumentationEngine.log                        10.05.2026 00:49:41    2139
dd_setup_20260510004930_041_Microsoft.CodeCoverage.Console.Targeted.log                             10.05.2026 00:49:41   63399
dd_setup_20260510004930_040_Microsoft.VisualStudio.TestTools.TestPlatform.V1.CLI.log                10.05.2026 00:49:40    5826
dd_setup_20260510004930_039_Microsoft.VisualStudio.TestTools.TestPlatform.V2.CLI.log                10.05.2026 00:49:40  338721
dd_setup_20260510004930_038_Microsoft.VisualStudio.VC.UnitTest.Desktop.Build.Core.log               10.05.2026 00:49:40   11211
dd_setup_20260510004930_037_Microsoft.VisualStudio.TestTools.TestPlatform.V1.CPP.log                10.05.2026 00:49:40    1260
dd_setup_20260510004930_036_Microsoft.VisualCpp.Tools.Common.Utils.log                              10.05.2026 00:49:40    3645
dd_setup_20260510004930_035_Microsoft.VisualCpp.Tools.Common.Utils.Resources.log                    10.05.2026 00:49:40    1299
dd_setup_20260510004930_034_Microsoft.VisualCpp.Servicing.Redist.log                                10.05.2026 00:49:39    3057
dd_setup_20260510004930_033_Microsoft.VisualStudio.VC.vcvars.log                                    10.05.2026 00:49:39    1419
dd_setup_20260510004930_032_Microsoft.VS.VC.vcvars.x86.Shortcuts.log                                10.05.2026 00:49:39     309
dd_setup_20260510004930_031_Microsoft.VS.VC.vcvars.x64.Shortcuts.log                                10.05.2026 00:49:39     309
dd_setup_20260510004930_030_Microsoft.Windows.UniversalCRT.Redistributable.Msi.log                  10.05.2026 00:49:39  424204
dd_setup_20260510004930_029_Microsoft.VisualStudio.VC.MSBuild.v170.x86.v143.log                     10.05.2026 00:49:39    1851
dd_setup_20260510004930_028_Microsoft.VisualStudio.VC.MSBuild.v170.X86.log                          10.05.2026 00:49:39    2967
dd_setup_20260510004930_027_Microsoft.VisualStudio.VC.MSBuild.v170.X64.v143.log                     10.05.2026 00:49:39    1827
dd_setup_20260510004930_026_Microsoft.VisualStudio.VC.MSBuild.v170.X64.log                          10.05.2026 00:49:38    2919
dd_setup_20260510004930_025_Microsoft.VisualStudio.VC.MSBuild.v170.ARM.v143.log                     10.05.2026 00:49:38    1827
dd_setup_20260510004930_024_Microsoft.VisualStudio.VC.MSBuild.v170.ARM.log                          10.05.2026 00:49:38    2919
dd_setup_20260510004930_023_Microsoft.VisualStudio.VC.MSBuild.v170.Base.log                         10.05.2026 00:49:38   66846
dd_setup_20260510004930_022_Microsoft.VisualStudio.VC.MSBuild.v170.Base.Resources.log               10.05.2026 00:49:38   30756
dd_setup_20260510004930_021_Microsoft.VisualStudio.Setup.WMIProvider.log                            10.05.2026 00:49:38  124332
dd_setup_20260510004930_020_Microsoft.VisualStudio.Setup.Configuration.Interop.log                  10.05.2026 00:49:37    1116
dd_setup_20260510004930_019_Microsoft.VisualStudio.Setup.Configuration.log                          10.05.2026 00:49:37  100052
dd_setup_20260510004930_018_Microsoft.VisualStudio.VsDevCmd.Ext.NetFxSdk.log                        10.05.2026 00:49:36     846
dd_setup_20260510004930_017_Microsoft.VisualStudio.VsDevCmd.Core.WinSdk.log                         10.05.2026 00:49:36     840
dd_setup_20260510004930_016_Microsoft.VisualStudio.VsDevCmd.Core.DotNet.log                         10.05.2026 00:49:36     840
dd_setup_20260510004930_015_Microsoft.VisualStudio.VC.DevCmd.log                                    10.05.2026 00:49:36    7566
dd_setup_20260510004930_014_Microsoft.VisualStudio.VC.DevCmd.Resources.log                          10.05.2026 00:49:36     984
dd_setup_20260510004930_013_Microsoft.VisualStudio.BuildTools.Resources.log                         10.05.2026 00:49:36     888
dd_setup_20260510004930_012_Microsoft.VisualStudio.Net.Eula.Resources.log                           10.05.2026 00:49:36     834
dd_setup_20260510004930_011_Microsoft.Build.Dependencies.log                                        10.05.2026 00:49:36  344712
dd_setup_20260510004930_010_Microsoft.Build.FileTracker.Msi.log                                     10.05.2026 00:49:36  187394
dd_setup_20260510004930_009_Microsoft.PythonTools.BuildCore.Vsix.log                                10.05.2026 00:49:35   13065
dd_setup_20260510004930_008_Microsoft.NuGet.Build.Tasks.Setup.log                                   10.05.2026 00:49:35    5292
dd_setup_20260510004930_007_Microsoft.CodeAnalysis.Compilers.log                                    10.05.2026 00:49:35   87028
dd_setup_20260510004930_006_Microsoft.VisualStudio.NativeImageSupport.log                           10.05.2026 00:49:35    1185
dd_setup_20260510004930_005_Microsoft.Build.log                                                     10.05.2026 00:49:35  211193
dd_setup_20260510004930_004_Microsoft.VisualStudio.NuGet.BuildTools.log                             10.05.2026 00:49:34  187125
dd_setup_20260510004930_003_Microsoft.Build.UnGAC.log                                               10.05.2026 00:49:34    1491
dd_setup_20260510004930_002_Microsoft.VisualStudio.VC.Icons.log                                     10.05.2026 00:49:34     744
dd_setup_20260510004930_000_TestMSI.log                                                             10.05.2026 00:49:33   62958
dd_setup_20260510004930_errors.log                                                                  10.05.2026 00:49:30       0
dd_setup_20260510004927.log                                                                         10.05.2026 00:49:28    5647
dd_setup_20260510004927_errors.log                                                                  10.05.2026 00:49:27       0
dd_vcredist_x86_20260508213711.log                                                                  08.05.2026 21:46:19    8775
dd_vcredist_x86_20260508213711_1_vcRuntimeAdditional_x86.log                                        08.05.2026 21:37:27  204762
dd_vcredist_x86_20260508213711_0_vcRuntimeMinimum_x86.log                                           08.05.2026 21:37:27  175786

```

</details>

### Copy-to-`inbox\logs\` summary

The script copied every `dd_*.log` it found in `%TEMP%` (which equals
`%USERPROFILE%\AppData\Local\Temp` on this single-user box, so no defensive
second pass was needed). Result:

- **1,940 `dd_*.log` files** copied successfully
- **0 failures**
- **151,304,993 bytes (~144 MB)** total in `inbox/logs/`

Per-file outcomes are in `01-snapshot-raw.txt` under section
`Copy dd_*.log -> inbox\logs (from both temp dirs)` (lines 2035-3974).

## Bootstrap log

```text
FOUND (2804 bytes), copied to inbox\logs\bootstrap-prereqs.log
--- last 50 lines ---
2026-05-10T02:03:02.9542127+02:00 bootstrap-prereqs starting (PID=9832, PSVersion=5.1.26100.8115)
2026-05-10T02:03:02.9702182+02:00 [INFO] winget found at C:\Users\Werguru\AppData\Local\Microsoft\WindowsApps\winget.exe
2026-05-10T02:03:02.9857085+02:00 [INFO] TortoiseSVN already present at C:\Program Files\TortoiseSVN\bin\svn.exe -- skipping.
2026-05-10T02:03:03.0541181+02:00 [INFO] VS install verb: 'install' at 'D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools' (existing instances found: 0)
2026-05-10T02:03:03.0551136+02:00 [INFO] Installing VS Build Tools 2022 (~10 GB) into D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools ...
2026-05-10T02:03:03.0561117+02:00 [INFO] This will take several minutes; the VS Installer UI shows progress.
2026-05-10T02:03:03.0571116+02:00 [INFO] Downloading VS Build Tools bootstrapper: https://aka.ms/vs/17/release/vs_BuildTools.exe
2026-05-10T02:03:05.9720277+02:00 [INFO] vs_BuildTools invoking: C:\Users\Werguru\AppData\Local\Temp\vs_BuildTools_9832.exe install --passive --wait --norestart --installPath "D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools" --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.Windows11SDK.22621
2026-05-10T02:05:06.4435156+02:00 [INFO] vs_BuildTools exit code: 0
2026-05-10T02:05:06.4476023+02:00 [INFO] vs_BuildTools final exit code: 0
2026-05-10T02:05:06.4811584+02:00 [ERROR] VS Build Tools install did not register the C++ workload. vs_BuildTools.exe
exited 0 but vswhere can't find Microsoft.VisualStudio.Component.VC.Tools.x86.x64
under any installed instance.

Likely causes:
  - Bootstrapper short-circuited because of leftover VS Installer state
  - --passive UI was closed before the install completed
  - VS Installer hit an error it couldn't recover from silently

Recovery options (any one works):
  A) Open 'Visual Studio Installer' from the Start menu, find
     'Visual Studio Build Tools 2022', click Modify, check
     'Desktop development with C++', and let it finish. Then re-run this
     script (or just rerun the worker installer; it will detect the
     completed install and skip the bootstrap).
  B) Run vs_BuildTools.exe manually with --passive replaced by --normal
     so you can see the full GUI:
       https://aka.ms/vs/17/release/vs_BuildTools.exe modify `
         --installPath "D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools" `
         --add Microsoft.VisualStudio.Workload.VCTools `
         --add Microsoft.VisualStudio.Component.Windows11SDK.22621

Diagnostic logs:
  - C:\Users\Werguru\AppData\Local\Temp\dd_setup_*.log       (bootstrapper download + handoff)
  - C:\ProgramData\Microsoft\VisualStudio\Packages\_Instances        (one folder per installed instance, with state.json)
--- end tail ---
```

The bootstrap script's own diagnostic check (the `[ERROR]` block) is what
flagged the failure: `vs_BuildTools.exe exited 0 but vswhere can't find
Microsoft.VisualStudio.Component.VC.Tools.x86.x64`. The remediation hints
the bootstrap printed (Recovery options A and B) are intentionally not
followed in this round — the brief said no installs.

## BuildTools install folder check (extra observation)

### `D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools`

```text
EXISTS: D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools
Recursive entry count: 10436
Top-level:

Name           Mode   LastWriteTime      
----           ----   -------------      
Common7        d----- 10.05.2026 02:03:32
ImportProjects d----- 10.05.2026 02:03:55
Licenses       d----- 10.05.2026 02:03:54
MSBuild        d----- 10.05.2026 02:03:20
Team Tools     d----- 10.05.2026 02:03:36
VB             d----- 10.05.2026 02:03:54
VC             d----- 10.05.2026 02:03:37
VC#            d----- 10.05.2026 02:03:55
Xml            d----- 10.05.2026 02:03:54

```

**Important.** The install folder *does* exist with **10,436 recursive
entries** including a top-level `VC` directory. Top-level mtimes cluster
around 02:03:20-02:03:55, which is during the install attempt (between
the bootstrap script firing `vs_BuildTools.exe` at 02:03:05.97 and the
`_Instances\0240ddbe` write at 02:05:03). So the installer:

1. Started, downloaded, unpacked into the install folder (~02:03:20-02:03:55).
2. Wrote `_Instances\0240ddbe` at 02:05:03.
3. Exited 0 at 02:05:06.

But: `vswhere` shows nothing. The `state.json` inside `_Instances\0240ddbe`
(not enumerated this round — would need a follow-up snapshot to dump it)
likely doesn't satisfy whatever schema vswhere uses to recognize a complete
instance.

### `C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools`

```text
MISSING: C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools

```

Confirms install was directed to D:\ as expected, no leftover at the default
C:\ path.

## VS-related processes at capture time

```text
  Id ProcessName      StartTime           Path                                     
  -- -----------      ---------           ----                                     
3292 TrustedInstaller 10.05.2026 11:37:44 C:\Windows\servicing\TrustedInstaller.exe

```

`TrustedInstaller.exe` started **at 11:37:44** — i.e., during this snapshot run
(snapshot generation timestamp is `2026-05-10T11:37:50` from the raw file
header), not lingering from yesterday's attempts. Most likely just servicing
activity unrelated to the bug. No `vs_*` / `setup.exe` / `Microsoft.VisualStudio.*` /
`VSInstaller` processes are running. So this is a clean state for
post-mortem reading of yesterday's logs — nothing is currently writing to
them.

## Notes / observations

1. **Ghost instance is real.** `_Instances\0240ddbe` exists with a recent
   mtime, but `vswhere` returns empty. Suggests either (a) `state.json` is
   incomplete/malformed, or (b) the registry-side bookkeeping that vswhere
   reads (e.g. `HKLM\Software\Microsoft\VisualStudio\Setup\Instances`) is
   missing the corresponding entry. A follow-up round could dump
   `_Instances\0240ddbe\state.json` and the relevant registry keys.

2. **Files were unpacked, install never committed.** 10,436 entries on disk
   under the install folder is consistent with "extracted but not registered."
   This is a different failure mode from "installer never started" — the
   installer ran, wrote payload, then aborted before publishing the instance.
   This narrows the hypothesis space considerably.

3. **`OsName` says "Windows 11 Home" but `WindowsProductName` says "Windows 10
   Home".** Standard PS 5.1 quirk on Win11; `WindowsProductName` reads from
   `HKLM\Software\Microsoft\Windows NT\CurrentVersion\ProductName` which MS
   never updated for Win11. Probably not relevant to the bug, but flagging
   it because the inconsistency could confuse follow-up analysis.

4. **`OsArchitecture` reads "64-biters"** — that's the **localized Norwegian
   string** for "64-bit" on this `nb-NO`-locale machine. Cosmetic, but
   relevant if any installer code is doing string comparison instead of
   reading the architecture from a stable API.

5. **PowerShell's CLR is .NET Framework 4.0.30319** — vs_BuildTools and the
   bootstrapper both depend on .NET; if there's any version mismatch with
   what the installer expects, that's another vector worth eliminating.

6. **No half-open VS Installer window.** No `setup.exe`, no `VSInstaller`,
   no `vs_*` processes. The taskbar should be clean.

## Open questions for dev-box-Claude

- Want me to dump `_Instances\0240ddbe\state.json` next round? That's
  almost certainly where the smoking gun lives.
- Want a focused grep over `dd_installer_elevated_20260510020313.log` and
  `dd_setup_20260510021015.log` for known failure tokens (e.g.
  `Setup completed`, `0x80*`, `Error`, `Exception`, `restart required`,
  `pendingFileRenameOperations`)? I can add that to a follow-up script.
- The "parens-free path" hypothesis from the debug doc — should we test
  that next, or first finish reading what we have?

## Files in this commit

- `inbox/00-handshake.md`
- `inbox/01-initial-snapshot.md` (this file)
- `inbox/01-snapshot-raw.txt` (verbatim PS output, 4,041 lines)
- `inbox/logs/bootstrap-prereqs.log` (2,804 bytes)
- `inbox/logs/dd_*.log` × 1,940 (~144 MB)
- `_helpers/snapshot.ps1` (the script that captured all of the above)

Sources:
- [`inbox/01-snapshot-raw.txt`](01-snapshot-raw.txt) — verbatim PowerShell output for every section above.
- [`inbox/logs/`](logs/) — surviving diagnostic logs from yesterday's attempts.

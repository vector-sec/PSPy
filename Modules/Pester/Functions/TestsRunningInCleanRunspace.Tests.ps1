function Invoke-PesterInJob ($ScriptBlock, $TestDrive)
{
    #TODO: there must be a safer way to determine this while I am in describe
    $PesterPath = (Get-Module -Name Pester).ModuleBase

    $ps = [powershell]::Create("NewRunspace")

    $null = $ps.AddCommand("Import-Module").AddParameter("Name", "$PesterPath/Pester.psd1")
    $null = $ps.Invoke()
    $ps.Commands.Clear()

    $null = $ps.AddCommand("Set-Content").AddParameter("Path","$TestDrive${directorySeparatorChar}Temp.Tests.ps1").AddParameter("Value",$scriptblock)
    $null = $ps.Invoke()
    $ps.Commands.Clear()

    $ps.AddStatement().AddCommand("Invoke-Pester").AddParameter("PassThru",$true).AddPArameter("Path","$TestDrive${directorySeparatorChar}")
    $results = $ps.Invoke()
    $ps.Commands.Clear()

    if ( $ps.streams.Error.count -gt 0 )
    {
        throw $ps.streams.Error[0]
    }
    $results

}

Describe "Tests running in clean runspace" {
    It -pending "It - Skip and Pending tests" {
        #tests to be run in different runspace using different Pester instance
        $TestSuite = {
            Describe 'It - Skip and Pending tests' {

                It "Skip without ScriptBlock" -skip
                It "Skip with empty ScriptBlock" -skip {}
                It "Skip with not empty ScriptBlock" -Skip {"something"}

                It "Implicit pending" {}
                It "Pending without ScriptBlock" -Pending
                It "Pending with empty ScriptBlock" -Pending {}
                It "Pending with not empty ScriptBlock" -Pending {"something"}
            }
        }

        $result = Invoke-PesterInJob -ScriptBlock $TestSuite -TestDrive $TESTDRIVE
        $result.SkippedCount | Should Be 3
        $result.PendingCount | Should Be 4
        $result.TotalCount | Should Be 7
    }

    It -pending "It - It without ScriptBlock fails" {
        #tests to be run in different runspace using different Pester instance
        $TestSuite = {
            Describe 'It without ScriptBlock fails' {
               It "Fails whole describe"
               It "is not run" { "but it would pass if it was run" }

            }
        }

        $result = Invoke-PesterInJob -ScriptBlock $TestSuite -TestDrive $TESTDRIVE
        $result.PassedCount | Should Be 0
        $result.FailedCount | Should Be 1

        $result.TotalCount | Should Be 1
    }

    It -pending "Invoke-Pester - PassThru output" {
        #tests to be run in different runspace using different Pester instance
        $TestSuite = {
            Describe 'PassThru output' {
               it "Passes" { "pass" }
               it "fails" { throw }
               it "Skipped" -Skip {}
               it "Pending" -Pending {}
            }
        }

        $result = Invoke-PesterInJob -ScriptBlock $TestSuite -TestDrive $TESTDRIVE
        $result.PassedCount | Should Be 1
        $result.FailedCount | Should Be 1
        $result.SkippedCount | Should Be 1
        $result.PendingCount | Should Be 1

        $result.TotalCount | Should Be 4
    }
}

Describe 'Guarantee It fail on setup or teardown fail (running in clean runspace)' {
    #these tests are kinda tricky. We need to ensure few things:
    #1) failing BeforeEach will fail the test. This is easy, just put the BeforeEach in the same try catch as the invocation
    #   of It code.
    #2) failing AfterEach will fail the test. To do that we might put the AfterEach to the same try as the It code, BUT we also
    #   want to guarantee that the AfterEach will run even if the test in It will fail. For this reason the AfterEach must be triggered in
    #   a finally block. And there we are not protected by the catch clause. So we need another try in the the finally to catch teardown block
    #   error. If we fail to do that the state won't be correctly cleaned up and we can get strange errors like: "You are still in It block", when
    #   running next test. For the same reason I am putting the "ensure all tests run" tests here. otherwise you get false positives because you cannot determine
    #   if the suite failed because of the whole suite failed or just a single test failed.

    It -pending 'It fails if BeforeEach fails' {
        $testSuite = {
            Describe 'Guarantee It fail on setup or teardown fail' {
                BeforeEach {
                    throw [System.InvalidOperationException] 'test exception'
                }

                It 'It fails if BeforeEach fails' {
                    $true
                }
            }
        }

        $result = Invoke-PesterInJob -ScriptBlock $testSuite -TestDrive $TESTDRIVE

        $result.FailedCount | Should Be 1
        $result.TestResult[0].FailureMessage | Should Be "test exception"
    }

    It -pending 'It fails if AfterEach fails' {
        $testSuite = {
            Describe 'Guarantee It fail on setup or teardown fail' {
                It 'It fails if AfterEach fails' {
                    $true
                }

                 AfterEach {
                    throw [System.InvalidOperationException] 'test exception'
                }
            }

            Describe 'Make sure all the tests in the suite run' {
                #when the previous test fails in after each and
                It 'It is pending' -Pending {}
            }
        }

        $result = Invoke-PesterInJob -ScriptBlock $testSuite -TestDrive $TESTDRIVE

        if ($result.PendingCount -ne 1)
        {
            throw "The test suite in separate runspace did not run to completion, it was likely terminated by an uncaught exception thrown in AfterEach."
        }

        $result.FailedCount | Should Be 1
        $result.TestResult[0].FailureMessage | Should Be "test exception"
    }
}

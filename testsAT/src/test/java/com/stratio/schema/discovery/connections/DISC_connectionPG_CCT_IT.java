package com.stratio.schema.discovery.connections;

import com.stratio.qa.cucumber.testng.CucumberRunner;
import com.stratio.qa.data.BrowsersDataProvider;
import com.stratio.tests.utils.BaseTest;
import cucumber.api.CucumberOptions;
import org.testng.annotations.Factory;
import org.testng.annotations.Test;

@CucumberOptions(features = { "src/test/resources/features/002_connections/002_disc_connectionPG_CCT.feature" },format = "json:target/cucumber.json")
public class DISC_connectionPG_CCT_IT extends BaseTest{

    @Factory(enabled = false, dataProviderClass = BrowsersDataProvider.class, dataProvider = "availableUniqueBrowsers")
    public DISC_connectionPG_CCT_IT(String browser) {
        this.browser = browser;
    }

    @Test(enabled = true, groups = {"connection_PG_CCT"})
    public void DISC_connectionPG() throws Exception {
        new CucumberRunner(this.getClass()).runCukes();
    }

}

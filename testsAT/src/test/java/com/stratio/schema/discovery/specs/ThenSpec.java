/*
 * © 2017 Stratio Big Data Inc., Sucursal en España. All rights reserved
 *
 * This software is a modification of the original software mesosphere/dcos-kafka-service licensed under the
 * Apache 2.0 license, a copy of which is included in root folder. This software contains proprietary information of
 * Stratio Big Data Inc., Sucursal en España and may not be revealed, sold, transferred, modified, distributed or
 * otherwise made available, licensed or sublicensed to third parties; nor reverse engineered, disassembled or
 * decompiled, without express written authorization from Stratio Big Data Inc., Sucursal en España.
 */
package com.stratio.schema.discovery.specs;

import cucumber.api.java.en.Then;

public class ThenSpec extends BaseSpec {

    public ThenSpec(Common spec) {
        this.commonspec = spec;
    }

    /*
    * closes opened database
    *
    */
    @Then("^I close database connection$")
    public void closeDatabase() throws Exception {
        this.commonspec.getConnection().close();
    }
}

import { getOwner } from "@ember/owner";
import { render, rerender } from "@ember/test-helpers";
import { module, test } from "qunit";
import CoreFabricators from "discourse/lib/fabricators";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import WebhookStatus from "admin/components/webhook-status";

module("Integration | Component | webhook-status", function (hooks) {
  setupRenderingTest(hooks);

  const DELIVERY_STATUSES = [
    { id: 1, name: "inactive" },
    { id: 2, name: "failed" },
    { id: 3, name: "successful" },
    { id: 4, name: "disabled" },
  ];

  test("deliveryStatus", async function (assert) {
    const webhook = new CoreFabricators(getOwner(this)).webhook();
    await render(<template>
      <WebhookStatus
        @deliveryStatuses={{DELIVERY_STATUSES}}
        @webhook={{webhook}}
      />
    </template>);

    assert.dom().hasText("Inactive");

    webhook.set("last_delivery_status", 2);

    await rerender();

    assert.dom().hasText("Failed");
  });

  test("iconName", async function (assert) {
    const webhook = new CoreFabricators(getOwner(this)).webhook();
    await render(<template>
      <WebhookStatus
        @deliveryStatuses={{DELIVERY_STATUSES}}
        @webhook={{webhook}}
      />
    </template>);

    assert.dom(".d-icon-far-circle").exists();

    webhook.set("last_delivery_status", 2);

    await rerender();

    assert.dom(".d-icon-times-circle").exists();
  });

  test("iconClass", async function (assert) {
    const webhook = new CoreFabricators(getOwner(this)).webhook();
    await render(<template>
      <WebhookStatus
        @deliveryStatuses={{DELIVERY_STATUSES}}
        @webhook={{webhook}}
      />
    </template>);

    assert.dom(".d-icon").hasClass("text-muted");

    webhook.set("last_delivery_status", 2);

    await rerender();

    assert.dom(".d-icon").hasClass("text-danger");
  });
});

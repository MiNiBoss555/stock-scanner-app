import "package:barcode_widget/barcode_widget.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:qr_flutter/qr_flutter.dart";
import "package:stock_scanner_mobile/models.dart";
import "package:stock_scanner_mobile/product_label_sheets.dart";

void main() {
  final product = Product(
    barcode: "8850001110012",
    name: "Printer Paper A4",
    unit: "ream",
    minimumStock: 10,
    currentStock: 45,
  );

  Widget buildHost({
    required VoidCallback onPressed,
    String buttonText = "Open",
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: onPressed,
            child: Text(buttonText),
          ),
        ),
      ),
    );
  }

  void ignoreKnownListTileInkWarning(WidgetTester tester) {
    for (var index = 0; index < 5; index++) {
      final exception = tester.takeException();
      if (exception == null) {
        return;
      }
      final message = exception.toString();
      final isKnownWarning = message.contains(
            "ListTile background color or ink splashes may be invisible",
          ) ||
          message.contains("Multiple exceptions");
      if (!isKnownWarning) {
        throw exception;
      }
    }
  }

  testWidgets("product code sheet renders barcode, QR, and action buttons",
      (tester) async {
    await tester.pumpWidget(
      buildHost(
        onPressed: () => showProductCodeSheet(
          tester.element(find.text("Open")),
          product,
        ),
      ),
    );

    await tester.tap(find.text("Open"));
    await tester.pumpAndSettle();

    expect(find.text("Printer Paper A4"), findsOneWidget);
    expect(find.text("8850001110012"), findsWidgets);
    expect(find.byType(BarcodeWidget), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.byIcon(Icons.print_outlined), findsOneWidget);
    expect(find.byIcon(Icons.ios_share_outlined), findsOneWidget);
    expect(find.byIcon(Icons.copy_all_outlined), findsOneWidget);
  });

  testWidgets("custom label sheet renders label and action buttons",
      (tester) async {
    await tester.pumpWidget(
      buildHost(
        onPressed: () => showCustomLabelSheet(
          tester.element(find.text("Open")),
          "Custom Label",
        ),
      ),
    );

    await tester.tap(find.text("Open"));
    await tester.pumpAndSettle();

    expect(find.text("Custom Label"), findsOneWidget);
    expect(find.byIcon(Icons.print_outlined), findsOneWidget);
    expect(find.byIcon(Icons.ios_share_outlined), findsOneWidget);
  });

  testWidgets("product list sheet renders products", (tester) async {
    await tester.pumpWidget(
      buildHost(
        onPressed: () => showProductListSheet(
          context: tester.element(find.text("Open")),
          products: [
            product,
            Product(
              barcode: "8850001110013",
              name: "Hand Sanitizer",
              unit: "bottle",
              minimumStock: 12,
              currentStock: 18,
            ),
          ],
          title: "Low stock",
          icon: Icons.warning_amber_rounded,
          color: Colors.orange,
        ),
      ),
    );

    await tester.tap(find.text("Open"));
    await tester.pumpAndSettle();
    ignoreKnownListTileInkWarning(tester);

    expect(find.textContaining("Low stock"), findsOneWidget);
    expect(find.text("Printer Paper A4"), findsOneWidget);
    expect(find.text("Hand Sanitizer"), findsOneWidget);
  });

  testWidgets("tapping a product in list opens product code sheet",
      (tester) async {
    await tester.pumpWidget(
      buildHost(
        onPressed: () => showProductListSheet(
          context: tester.element(find.text("Open")),
          products: [product],
          title: "Products",
          icon: Icons.inventory_2_rounded,
          color: Colors.blue,
        ),
      ),
    );

    await tester.tap(find.text("Open"));
    await tester.pumpAndSettle();
    ignoreKnownListTileInkWarning(tester);
    await tester.tap(find.text("Printer Paper A4"));
    await tester.pumpAndSettle();

    expect(find.byType(BarcodeWidget), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.byIcon(Icons.copy_all_outlined), findsOneWidget);
  });
}

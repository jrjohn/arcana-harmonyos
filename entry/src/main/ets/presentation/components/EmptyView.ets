/**
 * Empty state view component.
 */
@Component
export struct EmptyView {
  @Prop title: string = 'No items';
  @Prop message: string = '';
  @Prop showAction: boolean = false;
  @Prop actionText: string = 'Add';
  onAction: () => void = () => {};

  build() {
    Column() {
      // Empty icon
      Text('📋')
        .fontSize(64)

      Text(this.title)
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1F2937')
        .margin({ top: 24 })

      if (this.message.length > 0) {
        Text(this.message)
          .fontSize(14)
          .fontColor('#6B7280')
          .textAlign(TextAlign.Center)
          .margin({ top: 8, left: 32, right: 32 })
      }

      if (this.showAction) {
        Button(this.actionText)
          .type(ButtonType.Capsule)
          .backgroundColor('#7C3AED')
          .fontColor(Color.White)
          .fontSize(16)
          .padding({ left: 32, right: 32, top: 12, bottom: 12 })
          .margin({ top: 24 })
          .onClick(() => this.onAction())
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#F5F3FF')
  }
}

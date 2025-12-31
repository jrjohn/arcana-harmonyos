/**
 * Search bar component.
 */
@Component
export struct SearchBar {
  @Link searchText: string;
  @Prop placeholder: string = 'Search...';
  onTextChange: (text: string) => void = () => {};
  onClear: () => void = () => {};

  build() {
    Row() {
      // Search icon
      Image($r('sys.media.ohos_ic_public_search_filled'))
        .width(20)
        .height(20)
        .fillColor('#9CA3AF')
        .margin({ left: 12 })

      // Text input
      TextInput({ text: this.searchText, placeholder: this.placeholder })
        .layoutWeight(1)
        .height(40)
        .backgroundColor(Color.Transparent)
        .placeholderColor('#9CA3AF')
        .placeholderFont({ size: 16 })
        .fontSize(16)
        .fontColor('#1F2937')
        .padding({ left: 8, right: 8 })
        .onChange((value: string) => {
          this.searchText = value;
          this.onTextChange(value);
        })

      // Clear button
      if (this.searchText.length > 0) {
        Image($r('sys.media.ohos_ic_public_cancel_filled'))
          .width(20)
          .height(20)
          .fillColor('#9CA3AF')
          .margin({ right: 12 })
          .onClick(() => {
            this.searchText = '';
            this.onClear();
          })
      }
    }
    .width('100%')
    .height(48)
    .backgroundColor('#FFFFFF')
    .borderRadius(24)
    .border({ width: 1, color: '#E5E7EB' })
  }
}

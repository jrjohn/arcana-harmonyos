/**
 * Search bar component with localization support.
 */
@Component
export struct SearchBar {
  @Link searchText: string;
  @Prop placeholder: string = '';
  placeholderResource?: Resource;
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

      // Text input - use resource if provided, otherwise fallback to string
      if (this.placeholderResource) {
        TextInput({ text: this.searchText, placeholder: this.placeholderResource })
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
      } else {
        TextInput({ text: this.searchText, placeholder: this.placeholder || 'Search...' })
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
      }

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

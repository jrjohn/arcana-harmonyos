import { picker } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { Logger } from '../logging/Logger';

const TAG = 'PhotoPicker';

/**
 * Result of photo picking operation
 */
export interface PhotoPickResult {
  success: boolean;
  uri?: string;
  error?: string;
}

/**
 * Utility class for picking photos from the gallery
 */
export class PhotoPicker {
  /**
   * Opens the photo picker and returns the selected image URI
   */
  static async pickPhoto(context: common.UIAbilityContext): Promise<PhotoPickResult> {
    try {
      Logger.d(TAG, 'Opening photo picker');

      const photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;

      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      const result = await photoPicker.select(photoSelectOptions);

      if (result.photoUris && result.photoUris.length > 0) {
        const selectedUri = result.photoUris[0];
        Logger.d(TAG, `Photo selected: ${selectedUri}`);

        return {
          success: true,
          uri: selectedUri
        };
      } else {
        Logger.d(TAG, 'No photo selected');
        return {
          success: false,
          error: 'No photo selected'
        };
      }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      Logger.e(TAG, `Failed to pick photo: ${errorMessage}`);
      return {
        success: false,
        error: errorMessage
      };
    }
  }

  /**
   * Copies the selected photo to app sandbox and returns the new path
   * This is needed because the photo URI from picker might not be directly accessible
   */
  static async copyToAppSandbox(
    context: common.UIAbilityContext,
    sourceUri: string
  ): Promise<PhotoPickResult> {
    try {
      Logger.d(TAG, `Copying photo to sandbox: ${sourceUri}`);

      // Generate unique filename
      const timestamp = Date.now();
      const fileName = `avatar_${timestamp}.jpg`;
      const destPath = `${context.filesDir}/${fileName}`;

      // Open source file
      const sourceFile = fileIo.openSync(sourceUri, fileIo.OpenMode.READ_ONLY);

      // Create destination file
      const destFile = fileIo.openSync(destPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);

      // Read and write in chunks
      const bufferSize = 4096;
      const buffer = new ArrayBuffer(bufferSize);
      let bytesRead = fileIo.readSync(sourceFile.fd, buffer);

      while (bytesRead > 0) {
        if (bytesRead < bufferSize) {
          // Last chunk, only write what was read
          const lastBuffer = buffer.slice(0, bytesRead);
          fileIo.writeSync(destFile.fd, lastBuffer);
        } else {
          fileIo.writeSync(destFile.fd, buffer);
        }
        bytesRead = fileIo.readSync(sourceFile.fd, buffer);
      }

      // Close files
      fileIo.closeSync(sourceFile);
      fileIo.closeSync(destFile);

      Logger.d(TAG, `Photo copied to: ${destPath}`);

      return {
        success: true,
        uri: destPath
      };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      Logger.e(TAG, `Failed to copy photo: ${errorMessage}`);
      return {
        success: false,
        error: errorMessage
      };
    }
  }

  /**
   * Picks a photo and copies it to app sandbox
   * Returns the sandbox path for the image
   */
  static async pickAndSavePhoto(context: common.UIAbilityContext): Promise<PhotoPickResult> {
    // First pick the photo
    const pickResult = await PhotoPicker.pickPhoto(context);
    if (!pickResult.success || !pickResult.uri) {
      return pickResult;
    }

    // Then copy to sandbox
    return await PhotoPicker.copyToAppSandbox(context, pickResult.uri);
  }
}

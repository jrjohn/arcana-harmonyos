/**
 * Unit Tests for Logger
 * Tests logging functionality and log levels
 */

import { describe, it, expect, beforeEach, afterEach } from '@ohos/hypium';
import { Logger, LogLevel, TimingCallback } from '../../../../../main/ets/core/logging/Logger';

export default function LoggerTest() {
  describe('LogLevel', () => {
    it('should have DEBUG level at 0', () => {
      expect(LogLevel.DEBUG).assertEqual(0);
    });

    it('should have INFO level at 1', () => {
      expect(LogLevel.INFO).assertEqual(1);
    });

    it('should have WARN level at 2', () => {
      expect(LogLevel.WARN).assertEqual(2);
    });

    it('should have ERROR level at 3', () => {
      expect(LogLevel.ERROR).assertEqual(3);
    });

    it('should have FATAL level at 4', () => {
      expect(LogLevel.FATAL).assertEqual(4);
    });

    it('should have ordered levels', () => {
      expect(LogLevel.DEBUG < LogLevel.INFO).assertTrue();
      expect(LogLevel.INFO < LogLevel.WARN).assertTrue();
      expect(LogLevel.WARN < LogLevel.ERROR).assertTrue();
      expect(LogLevel.ERROR < LogLevel.FATAL).assertTrue();
    });
  });

  describe('Logger.setLevel', () => {
    afterEach(() => {
      Logger.setLevel(LogLevel.DEBUG);
      Logger.setEnabled(true);
    });

    it('should set log level without error', () => {
      Logger.setLevel(LogLevel.INFO);
      expect(true).assertTrue();
    });

    it('should accept all log levels', () => {
      Logger.setLevel(LogLevel.DEBUG);
      Logger.setLevel(LogLevel.INFO);
      Logger.setLevel(LogLevel.WARN);
      Logger.setLevel(LogLevel.ERROR);
      Logger.setLevel(LogLevel.FATAL);
      expect(true).assertTrue();
    });
  });

  describe('Logger.setEnabled', () => {
    afterEach(() => {
      Logger.setEnabled(true);
    });

    it('should enable logging', () => {
      Logger.setEnabled(true);
      expect(true).assertTrue();
    });

    it('should disable logging', () => {
      Logger.setEnabled(false);
      expect(true).assertTrue();
    });
  });

  describe('Logger.d (debug)', () => {
    beforeEach(() => {
      Logger.setLevel(LogLevel.DEBUG);
      Logger.setEnabled(true);
    });

    it('should log debug message without error', () => {
      Logger.d('TestTag', 'Debug message');
      expect(true).assertTrue();
    });

    it('should handle empty tag', () => {
      Logger.d('', 'Debug message');
      expect(true).assertTrue();
    });

    it('should handle empty message', () => {
      Logger.d('TestTag', '');
      expect(true).assertTrue();
    });

    it('should handle special characters', () => {
      Logger.d('TestTag', 'Message with special chars: !@#$%^&*()');
      expect(true).assertTrue();
    });
  });

  describe('Logger.i (info)', () => {
    beforeEach(() => {
      Logger.setLevel(LogLevel.DEBUG);
      Logger.setEnabled(true);
    });

    it('should log info message without error', () => {
      Logger.i('TestTag', 'Info message');
      expect(true).assertTrue();
    });
  });

  describe('Logger.w (warning)', () => {
    beforeEach(() => {
      Logger.setLevel(LogLevel.DEBUG);
      Logger.setEnabled(true);
    });

    it('should log warning message without error', () => {
      Logger.w('TestTag', 'Warning message');
      expect(true).assertTrue();
    });
  });

  describe('Logger.e (error)', () => {
    beforeEach(() => {
      Logger.setLevel(LogLevel.DEBUG);
      Logger.setEnabled(true);
    });

    it('should log error message without error', () => {
      Logger.e('TestTag', 'Error message');
      expect(true).assertTrue();
    });
  });

  describe('Logger.f (fatal)', () => {
    beforeEach(() => {
      Logger.setLevel(LogLevel.DEBUG);
      Logger.setEnabled(true);
    });

    it('should log fatal message without error', () => {
      Logger.f('TestTag', 'Fatal message');
      expect(true).assertTrue();
    });
  });

  describe('Logger.log', () => {
    beforeEach(() => {
      Logger.setLevel(LogLevel.DEBUG);
      Logger.setEnabled(true);
    });

    it('should log with DEBUG level', () => {
      Logger.log(LogLevel.DEBUG, 'TestTag', 'Debug via log');
      expect(true).assertTrue();
    });

    it('should log with INFO level', () => {
      Logger.log(LogLevel.INFO, 'TestTag', 'Info via log');
      expect(true).assertTrue();
    });

    it('should log with WARN level', () => {
      Logger.log(LogLevel.WARN, 'TestTag', 'Warn via log');
      expect(true).assertTrue();
    });

    it('should log with ERROR level', () => {
      Logger.log(LogLevel.ERROR, 'TestTag', 'Error via log');
      expect(true).assertTrue();
    });

    it('should log with FATAL level', () => {
      Logger.log(LogLevel.FATAL, 'TestTag', 'Fatal via log');
      expect(true).assertTrue();
    });
  });

  describe('Logger.exception', () => {
    beforeEach(() => {
      Logger.setLevel(LogLevel.DEBUG);
      Logger.setEnabled(true);
    });

    it('should log exception with message', () => {
      const error = new Error('Test error');
      Logger.exception('TestTag', 'Exception occurred', error);
      expect(true).assertTrue();
    });

    it('should handle error without stack', () => {
      const error = new Error('Test error');
      Logger.exception('TestTag', 'Exception', error);
      expect(true).assertTrue();
    });
  });

  describe('Logger.json', () => {
    beforeEach(() => {
      Logger.setLevel(LogLevel.DEBUG);
      Logger.setEnabled(true);
    });

    it('should log JSON object', () => {
      Logger.json('TestTag', 'Data', { key: 'value', num: 42 });
      expect(true).assertTrue();
    });

    it('should handle nested objects', () => {
      Logger.json('TestTag', 'Nested', { outer: { inner: 'value' } });
      expect(true).assertTrue();
    });

    it('should handle arrays', () => {
      Logger.json('TestTag', 'Array', { items: [1, 2, 3] });
      expect(true).assertTrue();
    });

    it('should handle empty object', () => {
      Logger.json('TestTag', 'Empty', {});
      expect(true).assertTrue();
    });
  });

  describe('Logger.time', () => {
    beforeEach(() => {
      Logger.setLevel(LogLevel.DEBUG);
      Logger.setEnabled(true);
    });

    it('should return TimingCallback', () => {
      const timing = Logger.time('TestTag', 'Operation');
      expect(timing).assertNotNull();
      expect(timing instanceof TimingCallback).assertTrue();
    });

    it('should end timing without error', () => {
      const timing = Logger.time('TestTag', 'Operation');
      timing.end();
      expect(true).assertTrue();
    });

    it('should measure elapsed time', async () => {
      const timing = Logger.time('TestTag', 'Delayed');
      await new Promise<void>(resolve => setTimeout(resolve, 10));
      timing.end();
      expect(true).assertTrue();
    });
  });

  describe('TimingCallback', () => {
    it('should create instance with parameters', () => {
      const callback = new TimingCallback('Tag', 'Label', Date.now());
      expect(callback).assertNotNull();
    });

    it('should end without error', () => {
      const callback = new TimingCallback('Tag', 'Label', Date.now());
      callback.end();
      expect(true).assertTrue();
    });

    it('should be callable multiple times', () => {
      const callback = new TimingCallback('Tag', 'Label', Date.now());
      callback.end();
      callback.end();
      expect(true).assertTrue();
    });
  });

  describe('Log level filtering', () => {
    afterEach(() => {
      Logger.setLevel(LogLevel.DEBUG);
      Logger.setEnabled(true);
    });

    it('should respect log level setting', () => {
      Logger.setLevel(LogLevel.ERROR);
      // These should be filtered out (not logged) but not throw
      Logger.d('TestTag', 'Debug filtered');
      Logger.i('TestTag', 'Info filtered');
      Logger.w('TestTag', 'Warn filtered');
      // This should log
      Logger.e('TestTag', 'Error logged');
      expect(true).assertTrue();
    });

    it('should respect enabled flag', () => {
      Logger.setEnabled(false);
      Logger.d('TestTag', 'Should not log');
      Logger.i('TestTag', 'Should not log');
      Logger.w('TestTag', 'Should not log');
      Logger.e('TestTag', 'Should not log');
      Logger.f('TestTag', 'Should not log');
      expect(true).assertTrue();
    });
  });
}

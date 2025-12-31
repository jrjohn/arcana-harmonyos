/**
 * Test Suite Entry Point
 * Registers all unit test modules
 */

import ContainerTest from './Container.test';
import RateLimiterTest from './RateLimiter.test';
import NavigationTest from './Navigation.test';
import MockServicesTest from './MockServices.test';
import LocalizationTest from './Localization.test';

export default function testsuite() {
  // Core DI Container Tests
  ContainerTest();

  // Network Rate Limiter Tests
  RateLimiterTest();

  // Navigation and Deep Linking Tests
  NavigationTest();

  // Mock Services Tests (Testing Infrastructure)
  MockServicesTest();

  // Localization Tests
  LocalizationTest();
}
